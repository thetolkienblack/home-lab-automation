#!/bin/bash

# Complete MySQL Database Migration Script
# Extracts credentials from .env files and migrates all databases to a target MySQL container
# Similar to the PostgreSQL migration script

set -e

echo "=== Complete MySQL Database Migration ==="
echo

# Configuration - Change these variables as needed
TARGET_MYSQL_CONTAINER="mysql8"  # Change this to your target MySQL container name
TARGET_MYSQL_ROOT_USER="root"    # Root user in target container
TARGET_MYSQL_ROOT_PASSWORD=""    # Will try to auto-detect or prompt

# Create dumps directory
DUMP_DIR="/tmp/mysql_dumps"
mkdir -p "$DUMP_DIR"
echo "✓ Created dump directory: $DUMP_DIR"

# Stacks directory
STACKS_DIR="/opt/docker/stacks"

echo
echo "=== Step 1: Extracting MySQL credentials from .env files ==="

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
declare -A DB_ROOT_PASSWORDS
declare -A DB_CONTAINERS

# Process each stack directory
for stack_dir in "$STACKS_DIR"/*; do
    if [ -d "$stack_dir" ]; then
        stack_name=$(basename "$stack_dir")
        env_file="$stack_dir/.env"
        
        if [ -f "$env_file" ]; then
            echo "Processing $stack_name..."
            
            # Extract MySQL credentials (try multiple possible variable names)
            db_name=$(extract_env_value "$env_file" "MYSQL_DATABASE")
            [ -z "$db_name" ] && db_name=$(extract_env_value "$env_file" "MYSQL_DB")
            
            db_user=$(extract_env_value "$env_file" "MYSQL_USER")
            db_password=$(extract_env_value "$env_file" "MYSQL_PASSWORD")
            db_root_password=$(extract_env_value "$env_file" "MYSQL_ROOT_PASSWORD")
            
            if [ -n "$db_name" ] && [ -n "$db_user" ] && [ -n "$db_password" ]; then
                echo "  Found database: $db_name (user: $db_user)"
                
                # Store information
                DB_NAMES["$stack_name"]="$db_name"
                DB_USERS["$stack_name"]="$db_user"
                DB_PASSWORDS["$stack_name"]="$db_password"
                DB_ROOT_PASSWORDS["$stack_name"]="$db_root_password"
                DB_CONTAINERS["$stack_name"]="${stack_name}_mysql"
                
                echo "  ✓ Extracted credentials for $stack_name"
            else
                echo "  ⚠ No complete MySQL credentials found in $stack_name"
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
    echo "No MySQL databases found to migrate. Exiting."
    exit 0
fi

# Check if target container exists
echo
echo "=== Checking target MySQL container: $TARGET_MYSQL_CONTAINER ==="
if ! docker ps | grep -q "$TARGET_MYSQL_CONTAINER"; then
    echo "✗ Target container '$TARGET_MYSQL_CONTAINER' not found or not running."
    echo "Available MySQL containers:"
    docker ps | grep mysql || echo "No MySQL containers found"
    echo
    echo "Please update TARGET_MYSQL_CONTAINER variable in this script to point to your target MySQL container."
    exit 1
fi

# Auto-detect root password for target container
if [ -z "$TARGET_MYSQL_ROOT_PASSWORD" ]; then
    echo "Attempting to auto-detect root password for $TARGET_MYSQL_CONTAINER..."
    
    # Try to find root password from environment
    TARGET_MYSQL_ROOT_PASSWORD=$(docker inspect "$TARGET_MYSQL_CONTAINER" --format='{{range .Config.Env}}{{println .}}{{end}}' | grep "MYSQL_ROOT_PASSWORD=" | cut -d'=' -f2)
    
    if [ -z "$TARGET_MYSQL_ROOT_PASSWORD" ]; then
        echo "Could not auto-detect root password."
        read -s -p "Please enter the root password for $TARGET_MYSQL_CONTAINER: " TARGET_MYSQL_ROOT_PASSWORD
        echo
    else
        echo "✓ Auto-detected root password"
    fi
fi

echo
echo "=== Step 2: Creating database dumps ==="

for stack in "${!DB_NAMES[@]}"; do
    db_name="${DB_NAMES[$stack]}"
    db_user="${DB_USERS[$stack]}"
    db_password="${DB_PASSWORDS[$stack]}"
    db_root_password="${DB_ROOT_PASSWORDS[$stack]}"
    container="${DB_CONTAINERS[$stack]}"
    
    echo "Dumping $db_name from container $container..."
    
    # Check if container exists and is running
    if ! docker ps | grep -q "$container"; then
        echo "  ⚠ Warning: Container $container not found or not running. Skipping $db_name."
        continue
    fi
    
    # Try different dump methods
    dump_success=false
    
    # Method 1: Try with the database user
    if [ -n "$db_password" ]; then
        echo "  Trying with user: $db_user"
        if docker exec "$container" mysqldump -u"$db_user" -p"$db_password" --databases "$db_name" --routines --triggers --single-transaction > "$DUMP_DIR/${db_name}_dump.sql" 2>/dev/null; then
            echo "  ✓ Successfully dumped $db_name (using $db_user)"
            dump_success=true
        fi
    fi
    
    # Method 2: Try with root user (if we have root password)
    if [ "$dump_success" = false ] && [ -n "$db_root_password" ]; then
        echo "  Trying with root user..."
        if docker exec "$container" mysqldump -uroot -p"$db_root_password" --databases "$db_name" --routines --triggers --single-transaction > "$DUMP_DIR/${db_name}_dump.sql" 2>/dev/null; then
            echo "  ✓ Successfully dumped $db_name (using root)"
            dump_success=true
        fi
    fi
    
    # Method 3: Try with root user without password
    if [ "$dump_success" = false ]; then
        echo "  Trying with root user (no password)..."
        if docker exec "$container" mysqldump -uroot --databases "$db_name" --routines --triggers --single-transaction > "$DUMP_DIR/${db_name}_dump.sql" 2>/dev/null; then
            echo "  ✓ Successfully dumped $db_name (using root, no password)"
            dump_success=true
        fi
    fi
    
    if [ "$dump_success" = false ]; then
        echo "  ✗ Failed to dump $db_name with any method. Skipping."
        continue
    fi
    
    # Verify dump file is not empty
    if [ ! -s "$DUMP_DIR/${db_name}_dump.sql" ]; then
        echo "  ✗ Dump file is empty for $db_name. Skipping."
        rm -f "$DUMP_DIR/${db_name}_dump.sql"
    fi
done

echo
echo "=== Step 3: Creating users and databases in $TARGET_MYSQL_CONTAINER ==="

# Create SQL script for user and database creation
sql_script="$DUMP_DIR/create_users_and_dbs.sql"
echo "-- Auto-generated SQL script for MySQL database migration" > "$sql_script"
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
-- $stack database and user
DROP DATABASE IF EXISTS \`$db_name\`;
CREATE DATABASE \`$db_name\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Create user if not exists (MySQL 8.0+ syntax)
CREATE USER IF NOT EXISTS '$db_user'@'%' IDENTIFIED BY '$db_password';
GRANT ALL PRIVILEGES ON \`$db_name\`.* TO '$db_user'@'%';

-- Also create user for localhost
CREATE USER IF NOT EXISTS '$db_user'@'localhost' IDENTIFIED BY '$db_password';
GRANT ALL PRIVILEGES ON \`$db_name\`.* TO '$db_user'@'localhost';

FLUSH PRIVILEGES;

EOF
done

# Execute the user and database creation
echo "Executing user and database creation in $TARGET_MYSQL_CONTAINER..."
if docker exec -i "$TARGET_MYSQL_CONTAINER" mysql -uroot -p"$TARGET_MYSQL_ROOT_PASSWORD" < "$sql_script"; then
    echo "✓ Successfully created users and databases"
else
    echo "✗ Failed to create users and databases"
    echo "SQL script location: $sql_script"
    exit 1
fi

echo
echo "=== Step 4: Importing data into $TARGET_MYSQL_CONTAINER ==="

for stack in "${!DB_NAMES[@]}"; do
    db_name="${DB_NAMES[$stack]}"
    db_user="${DB_USERS[$stack]}"
    db_password="${DB_PASSWORDS[$stack]}"
    dump_file="$DUMP_DIR/${db_name}_dump.sql"
    
    # Skip if dump doesn't exist
    if [ ! -f "$dump_file" ]; then
        echo "Skipping $db_name - no dump file found"
        continue
    fi
    
    echo "Importing $db_name into $TARGET_MYSQL_CONTAINER..."
    
    # Import the dump using root user (since dumps contain CREATE DATABASE statements)
    if docker exec -i "$TARGET_MYSQL_CONTAINER" mysql -uroot -p"$TARGET_MYSQL_ROOT_PASSWORD" < "$dump_file" 2>/dev/null; then
        echo "  ✓ Successfully imported $db_name"
    else
        echo "  ⚠ Import had warnings/errors for $db_name, checking if data was imported..."
        
        # Check if tables exist
        table_count=$(docker exec "$TARGET_MYSQL_CONTAINER" mysql -uroot -p"$TARGET_MYSQL_ROOT_PASSWORD" -e "USE \`$db_name\`; SELECT COUNT(*) as count FROM information_schema.tables WHERE table_schema = '$db_name';" 2>/dev/null | tail -n1)
        
        if [ "$table_count" -gt 0 ] 2>/dev/null; then
            echo "  ✓ Import completed with $table_count tables (warnings may be normal)"
        else
            echo "  ✗ Import may have failed - no tables found"
        fi
    fi
done

echo
echo "=== Step 5: Verification ==="

echo "Listing all databases in $TARGET_MYSQL_CONTAINER:"
docker exec "$TARGET_MYSQL_CONTAINER" mysql -uroot -p"$TARGET_MYSQL_ROOT_PASSWORD" -e "SHOW DATABASES;"

echo
echo "Listing all users in $TARGET_MYSQL_CONTAINER:"
docker exec "$TARGET_MYSQL_CONTAINER" mysql -uroot -p"$TARGET_MYSQL_ROOT_PASSWORD" -e "SELECT User, Host FROM mysql.user WHERE User NOT IN ('mysql.sys', 'mysql.session', 'mysql.infoschema', 'root');"

echo
echo "Detailed verification for each imported database:"

for stack in "${!DB_NAMES[@]}"; do
    db_name="${DB_NAMES[$stack]}"
    db_user="${DB_USERS[$stack]}"
    db_password="${DB_PASSWORDS[$stack]}"
    
    if [ -f "$DUMP_DIR/${db_name}_dump.sql" ]; then
        echo "--- Database: $db_name ---"
        
        # Test connection with database user
        if docker exec "$TARGET_MYSQL_CONTAINER" mysql -u"$db_user" -p"$db_password" -e "USE \`$db_name\`; SELECT 1;" >/dev/null 2>&1; then
            echo "  ✓ Connection test passed for user $db_user"
            
            # Count tables
            table_count=$(docker exec "$TARGET_MYSQL_CONTAINER" mysql -u"$db_user" -p"$db_password" -e "USE \`$db_name\`; SELECT COUNT(*) as count FROM information_schema.tables WHERE table_schema = '$db_name';" 2>/dev/null | tail -n1)
            echo "  ✓ Tables found: $table_count"
            
            # List tables
            if [ "$table_count" -gt 0 ] 2>/dev/null; then
                echo "  Tables:"
                docker exec "$TARGET_MYSQL_CONTAINER" mysql -u"$db_user" -p"$db_password" -e "USE \`$db_name\`; SHOW TABLES;" 2>/dev/null | tail -n +2 | sed 's/^/    - /' || echo "    (Could not list tables)"
            fi
        else
            echo "  ✗ Connection test failed for user $db_user"
        fi
        echo
    fi
done

echo "=== Migration Summary ==="
echo "✓ Extracted credentials from .env files"
echo "✓ Created dumps in: $DUMP_DIR"
echo "✓ Created users and databases in $TARGET_MYSQL_CONTAINER"
echo "✓ Imported data (check verification above)"
echo
echo "Files created:"
echo "  - SQL script: $sql_script"
echo "  - Dump files: $DUMP_DIR/*_dump.sql"
echo
echo "=== Next Steps ==="
echo "1. Verify your applications work with $TARGET_MYSQL_CONTAINER:"
for stack in "${!DB_NAMES[@]}"; do
    db_name="${DB_NAMES[$stack]}"
    db_user="${DB_USERS[$stack]}"
    echo "   docker exec -it $TARGET_MYSQL_CONTAINER mysql -u$db_user -p -D$db_name"
done
echo
echo "2. Update your docker-compose.yml files to:"
echo "   - Change database host to '$TARGET_MYSQL_CONTAINER'"
echo "   - Remove old database containers"
echo "   - Use the same network as $TARGET_MYSQL_CONTAINER"
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
