#!/bin/bash

# Complete PostgreSQL Database Migration Script
# Extracts credentials from .env files and migrates all databases to postgres16
# Excludes "demo" database as it's already in postgres16

set -e

echo "=== Complete PostgreSQL Database Migration to postgres16 ==="
echo "Excluding 'demo' database (already exists in postgres16)"
echo

# Create dumps directory
DUMP_DIR="/tmp/postgres_dumps"
mkdir -p "$DUMP_DIR"
echo "✓ Created dump directory: $DUMP_DIR"

# Stacks directory
STACKS_DIR="/opt/docker/stacks"

echo
echo "=== Step 1: Extracting database credentials from .env files ==="

# Function to extract value from env file
extract_env_value() {
    local file="$1"
    local key="$2"
    grep "^${key}=" "$file" 2>/dev/null | cut -d'=' -f2- | tr -d '"'"'"
}

# Initialize arrays to store database information
declare -A DB_NAMES
declare -A DB_USERS
declare -A DB_PASSWORDS
declare -A DB_CONTAINERS

# Process each stack directory
for stack_dir in "$STACKS_DIR"/*; do
    if [ -d "$stack_dir" ]; then
        stack_name=$(basename "$stack_dir")
        env_file="$stack_dir/.env"

        # Skip databases stack (contains demo db)
        if [ "$stack_name" = "databases" ]; then
            echo "Skipping databases stack (demo database already in postgres16)"
            continue
        fi

        if [ -f "$env_file" ]; then
            echo "Processing $stack_name..."

            # Extract PostgreSQL credentials
            db_name=$(extract_env_value "$env_file" "POSTGRES_DB")
            db_user=$(extract_env_value "$env_file" "POSTGRES_USER")
            db_password=$(extract_env_value "$env_file" "POSTGRES_PASSWORD")

            if [ -n "$db_name" ] && [ -n "$db_user" ] && [ -n "$db_password" ]; then
                echo "  Found database: $db_name (user: $db_user)"

                # Store information
                DB_NAMES["$stack_name"]="$db_name"
                DB_USERS["$stack_name"]="$db_user"
                DB_PASSWORDS["$stack_name"]="$db_password"
                DB_CONTAINERS["$stack_name"]="${stack_name}_postgres"

                echo "  ✓ Extracted credentials for $stack_name"
            else
                echo "  ⚠ No complete PostgreSQL credentials found in $stack_name"
            fi
        else
            echo "  ⚠ No .env file found in $stack_name"
        fi
    fi
done

# Display found databases
echo
echo "Found databases to migrate:"
for stack in "${!DB_NAMES[@]}"; do
    echo "  - ${DB_NAMES[$stack]} (${DB_USERS[$stack]}@${DB_CONTAINERS[$stack]})"
done

if [ ${#DB_NAMES[@]} -eq 0 ]; then
    echo "No databases found to migrate. Exiting."
    exit 0
fi

echo
echo "=== Step 2: Creating database dumps ==="

for stack in "${!DB_NAMES[@]}"; do
    db_name="${DB_NAMES[$stack]}"
    db_user="${DB_USERS[$stack]}"
    container="${DB_CONTAINERS[$stack]}"

    echo "Dumping $db_name from container $container..."

    # Check if container exists and is running
    if ! docker ps | grep -q "$container"; then
        echo "  ⚠ Warning: Container $container not found or not running. Skipping $db_name."
        continue
    fi

    # Create database dump
    if docker exec "$container" pg_dump -U "$db_user" "$db_name" > "$DUMP_DIR/${db_name}_dump.sql" 2>/dev/null; then
        echo "  ✓ Successfully dumped $db_name"
    else
        echo "  ✗ Failed to dump $db_name - trying with postgres user..."
        if docker exec "$container" pg_dump -U postgres "$db_name" > "$DUMP_DIR/${db_name}_dump.sql" 2>/dev/null; then
            echo "  ✓ Successfully dumped $db_name (using postgres user)"
        else
            echo "  ✗ Failed to dump $db_name completely. Skipping."
            continue
        fi
    fi

    # Verify dump file is not empty
    if [ ! -s "$DUMP_DIR/${db_name}_dump.sql" ]; then
        echo "  ✗ Dump file is empty for $db_name. Skipping."
        rm -f "$DUMP_DIR/${db_name}_dump.sql"
    fi
done

echo
echo "=== Step 3: Creating users and databases in postgres16 ==="

# Create SQL script for user and database creation
sql_script="$DUMP_DIR/create_users_and_dbs.sql"
echo "-- Auto-generated SQL script for database migration" > "$sql_script"
echo "-- Created: $(date)" >> "$sql_script"
echo "" >> "$sql_script"

for stack in "${!DB_NAMES[@]}"; do
    db_name="${DB_NAMES[$stack]}"
    db_user="${DB_USERS[$stack]}"
    db_password="${DB_PASSWORDS[$stack]}"

    # Skip if dump doesn't exist
    if [ ! -f "$DUMP_DIR/${db_name}_dump.sql" ]; then
        continue
    fi

    echo "Adding $db_name to creation script..."

    cat >> "$sql_script" << EOF
-- $stack database
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$db_user') THEN
        CREATE USER $db_user WITH PASSWORD '$db_password';
    END IF;
END
\$\$;

DROP DATABASE IF EXISTS $db_name;
CREATE DATABASE $db_name OWNER $db_user;
GRANT ALL PRIVILEGES ON DATABASE $db_name TO $db_user;
ALTER USER $db_user CREATEDB;

EOF
done

# Execute the user and database creation
echo "Executing user and database creation in postgres16..."
if docker exec -i postgres16 psql -U demo < "$sql_script"; then
    echo "✓ Successfully created users and databases"
else
    echo "✗ Failed to create users and databases"
    echo "SQL script location: $sql_script"
    exit 1
fi

echo
echo "=== Step 4: Importing data into postgres16 ==="

for stack in "${!DB_NAMES[@]}"; do
    db_name="${DB_NAMES[$stack]}"
    db_user="${DB_USERS[$stack]}"
    dump_file="$DUMP_DIR/${db_name}_dump.sql"

    # Skip if dump doesn't exist
    if [ ! -f "$dump_file" ]; then
        echo "Skipping $db_name - no dump file found"
        continue
    fi

    echo "Importing $db_name into postgres16..."

    # Import the dump
    if docker exec -i postgres16 psql -U "$db_user" -d "$db_name" < "$dump_file" 2>/dev/null; then
        echo "  ✓ Successfully imported $db_name"
    else
        echo "  ⚠ Import had warnings/errors for $db_name, checking if data was imported..."

        # Check if tables exist
        table_count=$(docker exec postgres16 psql -U "$db_user" -d "$db_name" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null | tr -d ' \n')

        if [ "$table_count" -gt 0 ] 2>/dev/null; then
            echo "  ✓ Import completed with $table_count tables (warnings may be normal)"
        else
            echo "  ✗ Import may have failed - no tables found"
        fi
    fi
done

echo
echo "=== Step 5: Verification ==="

echo "Listing all databases in postgres16:"
# Try with different superusers
for superuser in "postgres" "demo" "root"; do
    if docker exec postgres16 psql -U "$superuser" -c "\l" 2>/dev/null; then
        break
    fi
done

echo
echo "Detailed verification for each imported database:"

for stack in "${!DB_NAMES[@]}"; do
    db_name="${DB_NAMES[$stack]}"
    db_user="${DB_USERS[$stack]}"

    if [ -f "$DUMP_DIR/${db_name}_dump.sql" ]; then
        echo "--- Database: $db_name ---"

        # Test connection
        if docker exec postgres16 psql -U "$db_user" -d "$db_name" -c "\q" 2>/dev/null; then
            echo "  ✓ Connection test passed"

            # Count tables
            table_count=$(docker exec postgres16 psql -U "$db_user" -d "$db_name" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null | tr -d ' \n')
            echo "  ✓ Tables found: $table_count"

            # List tables
            if [ "$table_count" -gt 0 ] 2>/dev/null; then
                echo "  Tables:"
                docker exec postgres16 psql -U "$db_user" -d "$db_name" -c "\dt" 2>/dev/null | grep "public" | awk '{print "    - " $3}' || echo "    (Could not list tables)"
            fi
        else
            echo "  ✗ Connection test failed"
        fi
        echo
    fi
done

echo "=== Migration Summary ==="
echo "✓ Extracted credentials from .env files"
echo "✓ Created dumps in: $DUMP_DIR"
echo "✓ Created users and databases in postgres16"
echo "✓ Imported data (check verification above)"
echo "✓ Excluded demo database (already in postgres16)"
echo
echo "Files created:"
echo "  - SQL script: $sql_script"
echo "  - Dump files: $DUMP_DIR/*_dump.sql"
echo
echo "=== Next Steps ==="
echo "1. Verify your applications work with postgres16:"
for stack in "${!DB_NAMES[@]}"; do
    db_name="${DB_NAMES[$stack]}"
    db_user="${DB_USERS[$stack]}"
    echo "   docker exec -it postgres16 psql -U $db_user -d $db_name"
done
echo
echo "2. Update your docker-compose.yml files to:"
echo "   - Change database host to 'postgres16'"
echo "   - Remove old database containers"
echo "   - Use the same network as postgres16"
echo
echo "3. Test each application stack:"
echo "   - docker-compose down"
echo "   - docker-compose up -d"
echo "   - docker-compose logs -f"
echo
echo "4. When everything works, remove old containers:"
for stack in "${!DB_CONTAINERS[@]}"; do
    container="${DB_CONTAINERS[$stack]}"
    echo "   docker stop $container && docker rm $container"
done
echo
echo "Migration completed!"
