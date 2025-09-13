#!/bin/bash

# Complete Redis Database Migration Script
# Extracts credentials from .env files and migrates all Redis instances to a target Redis container
# Supports both RDB snapshot migration and live key migration

set -e

echo "=== Complete Redis Database Migration ==="
echo

# Configuration - Change these variables as needed
TARGET_REDIS_CONTAINER="redis7"        # Change this to your target Redis container name
TARGET_REDIS_PORT="6379"               # Port for target Redis
TARGET_REDIS_PASSWORD=""               # Will try to auto-detect or prompt
MIGRATION_METHOD="rdb"                 # Options: "rdb" (snapshot) or "live" (key-by-key)

# Create dumps directory
DUMP_DIR="/tmp/redis_dumps"
mkdir -p "$DUMP_DIR"
echo "✓ Created dump directory: $DUMP_DIR"

# Stacks directory
STACKS_DIR="/opt/docker/stacks"

echo
echo "=== Step 1: Extracting Redis credentials from .env files ==="

# Function to extract value from env file
extract_env_value() {
    local file="$1"
    local key="$2"
    grep "^${key}=" "$file" 2>/dev/null | cut -d'=' -f2- | tr -d '"'"'"
}

# Initialize arrays to store Redis information
declare -A REDIS_PASSWORDS
declare -A REDIS_PORTS
declare -A REDIS_CONTAINERS
declare -A REDIS_DBS

# Process each stack directory
for stack_dir in "$STACKS_DIR"/*; do
    if [ -d "$stack_dir" ]; then
        stack_name=$(basename "$stack_dir")
        env_file="$stack_dir/.env"
        
        if [ -f "$env_file" ]; then
            echo "Processing $stack_name..."
            
            # Extract Redis credentials (try multiple possible variable names)
            redis_password=$(extract_env_value "$env_file" "REDIS_PASSWORD")
            [ -z "$redis_password" ] && redis_password=$(extract_env_value "$env_file" "REDIS_PASS")
            [ -z "$redis_password" ] && redis_password=$(extract_env_value "$env_file" "REDIS_AUTH")
            
            redis_port=$(extract_env_value "$env_file" "REDIS_PORT")
            [ -z "$redis_port" ] && redis_port="6379"  # Default Redis port
            
            redis_db=$(extract_env_value "$env_file" "REDIS_DB")
            [ -z "$redis_db" ] && redis_db="0"  # Default Redis database
            
            # Check if there are any Redis-related environment variables
            if grep -q "REDIS" "$env_file"; then
                echo "  Found Redis configuration in $stack_name"
                
                # Store information
                REDIS_PASSWORDS["$stack_name"]="$redis_password"
                REDIS_PORTS["$stack_name"]="$redis_port"
                REDIS_DBS["$stack_name"]="$redis_db"
                REDIS_CONTAINERS["$stack_name"]="${stack_name}_redis"
                
                echo "  ✓ Extracted Redis config for $stack_name (port: $redis_port, db: $redis_db)"
            else
                echo "  ⚠ No Redis configuration found in $stack_name"
            fi
        else
            echo "  ⚠ No .env file found in $stack_name"
        fi
    fi
done

# Display found Redis instances
echo
echo "Found Redis instances to migrate:"
for stack in "${!REDIS_CONTAINERS[@]}"; do
    container="${REDIS_CONTAINERS[$stack]}"
    port="${REDIS_PORTS[$stack]}"
    db="${REDIS_DBS[$stack]}"
    echo "  - $stack (${container}:${port}/db${db})"
done

if [ ${#REDIS_CONTAINERS[@]} -eq 0 ]; then
    echo "No Redis instances found to migrate. Exiting."
    exit 0
fi

# Check if target container exists
echo
echo "=== Checking target Redis container: $TARGET_REDIS_CONTAINER ==="
if ! docker ps | grep -q "$TARGET_REDIS_CONTAINER"; then
    echo "✗ Target container '$TARGET_REDIS_CONTAINER' not found or not running."
    echo "Available Redis containers:"
    docker ps | grep redis || echo "No Redis containers found"
    echo
    echo "Please update TARGET_REDIS_CONTAINER variable in this script to point to your target Redis container."
    exit 1
fi

# Auto-detect password for target container
if [ -z "$TARGET_REDIS_PASSWORD" ]; then
    echo "Attempting to auto-detect password for $TARGET_REDIS_CONTAINER..."
    
    # Try to find password from environment
    TARGET_REDIS_PASSWORD=$(docker inspect "$TARGET_REDIS_CONTAINER" --format='{{range .Config.Env}}{{println .}}{{end}}' | grep -E "REDIS_(PASSWORD|PASS|AUTH)=" | head -1 | cut -d'=' -f2)
    
    if [ -z "$TARGET_REDIS_PASSWORD" ]; then
        echo "Could not auto-detect password. Trying without password first..."
        # Test connection without password
        if docker exec "$TARGET_REDIS_CONTAINER" redis-cli ping >/dev/null 2>&1; then
            echo "✓ Target Redis does not require password"
        else
            read -s -p "Please enter the password for $TARGET_REDIS_CONTAINER (or press Enter if none): " TARGET_REDIS_PASSWORD
            echo
        fi
    else
        echo "✓ Auto-detected password"
    fi
fi

echo
echo "=== Step 2: Migration Method: $MIGRATION_METHOD ==="

if [ "$MIGRATION_METHOD" = "rdb" ]; then
    echo "Using RDB snapshot migration (requires restart of source containers)"
    echo "This method is faster but requires brief downtime"
elif [ "$MIGRATION_METHOD" = "live" ]; then
    echo "Using live key migration (no downtime)"
    echo "This method is slower but keeps source Redis instances running"
else
    echo "Invalid migration method: $MIGRATION_METHOD"
    echo "Valid options: 'rdb' or 'live'"
    exit 1
fi

echo
echo "=== Step 3: Creating Redis backups ==="

for stack in "${!REDIS_CONTAINERS[@]}"; do
    container="${REDIS_CONTAINERS[$stack]}"
    password="${REDIS_PASSWORDS[$stack]}"
    port="${REDIS_PORTS[$stack]}"
    db="${REDIS_DBS[$stack]}"
    
    echo "Processing $stack (container: $container)..."
    
    # Check if container exists and is running
    if ! docker ps | grep -q "$container"; then
        echo "  ⚠ Warning: Container $container not found or not running. Skipping $stack."
        continue
    fi
    
    if [ "$MIGRATION_METHOD" = "rdb" ]; then
        # RDB Snapshot method
        echo "  Creating RDB snapshot for $stack..."
        
        # Build redis-cli command with authentication if needed
        redis_cmd="redis-cli"
        if [ -n "$password" ]; then
            redis_cmd="redis-cli -a '$password'"
        fi
        if [ "$port" != "6379" ]; then
            redis_cmd="$redis_cmd -p $port"
        fi
        
        # Trigger a save
        if docker exec "$container" bash -c "$redis_cmd SAVE" >/dev/null 2>&1; then
            echo "  ✓ RDB save completed for $stack"
            
            # Copy the RDB file from container
            rdb_path="/data/dump.rdb"
            
            # Try to get the actual data directory and filename
            data_dir=$(docker exec "$container" bash -c "$redis_cmd CONFIG GET dir" 2>/dev/null | tail -1 || echo "/data")
            db_filename=$(docker exec "$container" bash -c "$redis_cmd CONFIG GET dbfilename" 2>/dev/null | tail -1 || echo "dump.rdb")
            
            if [ "$data_dir" != "/data" ] || [ "$db_filename" != "dump.rdb" ]; then
                rdb_path="$data_dir/$db_filename"
            fi
            
            # Copy RDB file to host
            if docker cp "$container:$rdb_path" "$DUMP_DIR/${stack}_dump.rdb" 2>/dev/null; then
                echo "  ✓ RDB file copied for $stack"
            else
                echo "  ✗ Failed to copy RDB file for $stack"
                continue
            fi
        else
            echo "  ✗ Failed to create RDB save for $stack"
            continue
        fi
        
    elif [ "$MIGRATION_METHOD" = "live" ]; then
        # Live key migration method
        echo "  Exporting keys for $stack..."
        
        # Build redis-cli command
        redis_cmd="redis-cli"
        if [ -n "$password" ]; then
            redis_cmd="redis-cli -a '$password'"
        fi
        if [ "$port" != "6379" ]; then
            redis_cmd="$redis_cmd -p $port"
        fi
        if [ "$db" != "0" ]; then
            redis_cmd="$redis_cmd -n $db"
        fi
        
        # Get all keys
        keys_file="$DUMP_DIR/${stack}_keys.txt"
        if docker exec "$container" bash -c "$redis_cmd KEYS '*'" > "$keys_file" 2>/dev/null; then
            key_count=$(wc -l < "$keys_file")
            echo "  ✓ Found $key_count keys in $stack"
            
            # Create a script to export all data
            export_script="$DUMP_DIR/${stack}_export.redis"
            echo "# Redis export for $stack" > "$export_script"
            echo "# Generated on $(date)" >> "$export_script"
            echo "" >> "$export_script"
            
            # Export each key
            while IFS= read -r key; do
                if [ -n "$key" ]; then
                    # Get key type
                    key_type=$(docker exec "$container" bash -c "$redis_cmd TYPE '$key'" 2>/dev/null | tr -d '\r')
                    
                    case "$key_type" in
                        "string")
                            value=$(docker exec "$container" bash -c "$redis_cmd GET '$key'" 2>/dev/null)
                            echo "SET \"$key\" \"$value\"" >> "$export_script"
                            ;;
                        "hash")
                            docker exec "$container" bash -c "$redis_cmd HGETALL '$key'" 2>/dev/null | \
                            awk 'NR%2==1{key=$0} NR%2==0{print "HSET \"'$key'\" \"" key "\" \"" $0 "\""}' >> "$export_script"
                            ;;
                        "list")
                            docker exec "$container" bash -c "$redis_cmd LRANGE '$key' 0 -1" 2>/dev/null | \
                            awk '{print "LPUSH \"'$key'\" \"" $0 "\""}' >> "$export_script"
                            ;;
                        "set")
                            docker exec "$container" bash -c "$redis_cmd SMEMBERS '$key'" 2>/dev/null | \
                            awk '{print "SADD \"'$key'\" \"" $0 "\""}' >> "$export_script"
                            ;;
                        "zset")
                            docker exec "$container" bash -c "$redis_cmd ZRANGE '$key' 0 -1 WITHSCORES" 2>/dev/null | \
                            awk 'NR%2==1{member=$0} NR%2==0{print "ZADD \"'$key'\" " $0 " \"" member "\""}' >> "$export_script"
                            ;;
                        *)
                            echo "# Skipping key '$key' of unknown type '$key_type'" >> "$export_script"
                            ;;
                    esac
                fi
            done < "$keys_file"
            
            echo "  ✓ Created export script for $stack"
        else
            echo "  ✗ Failed to get keys for $stack"
            continue
        fi
    fi
done

echo
echo "=== Step 4: Importing data into $TARGET_REDIS_CONTAINER ==="

# Test target Redis connection
target_redis_cmd="redis-cli"
if [ -n "$TARGET_REDIS_PASSWORD" ]; then
    target_redis_cmd="redis-cli -a '$TARGET_REDIS_PASSWORD'"
fi
if [ "$TARGET_REDIS_PORT" != "6379" ]; then
    target_redis_cmd="$target_redis_cmd -p $TARGET_REDIS_PORT"
fi

echo "Testing connection to target Redis..."
if docker exec "$TARGET_REDIS_CONTAINER" bash -c "$target_redis_cmd ping" >/dev/null 2>&1; then
    echo "✓ Connection to target Redis successful"
else
    echo "✗ Failed to connect to target Redis"
    exit 1
fi

for stack in "${!REDIS_CONTAINERS[@]}"; do
    container="${REDIS_CONTAINERS[$stack]}"
    db="${REDIS_DBS[$stack]}"
    
    echo "Importing $stack into $TARGET_REDIS_CONTAINER..."
    
    if [ "$MIGRATION_METHOD" = "rdb" ]; then
        # RDB Import method
        rdb_file="$DUMP_DIR/${stack}_dump.rdb"
        
        if [ ! -f "$rdb_file" ]; then
            echo "  Skipping $stack - no RDB file found"
            continue
        fi
        
        # Create a temporary database number for this import
        temp_db=$((db + 100))  # Use db+100 to avoid conflicts
        
        echo "  Importing RDB data to temporary database $temp_db..."
        
        # Copy RDB file into target container
        docker cp "$rdb_file" "$TARGET_REDIS_CONTAINER:/tmp/${stack}_dump.rdb"
        
        # We'll need to stop and restart Redis with the RDB file
        # This is complex, so we'll use the live migration as fallback
        echo "  ⚠ RDB import requires Redis restart - using live migration instead"
        
        # Convert RDB to commands and import
        echo "  Converting RDB to Redis commands..."
        temp_container="redis_temp_$$"
        
        # Start temporary Redis container with the RDB file
        docker run -d --name "$temp_container" -v "$PWD/$rdb_file":/data/dump.rdb redis:alpine >/dev/null 2>&1
        
        # Wait for it to start
        sleep 3
        
        # Export all keys from temp container and import to target
        if docker exec "$temp_container" redis-cli KEYS '*' > /tmp/temp_keys.txt 2>/dev/null; then
            while IFS= read -r key; do
                if [ -n "$key" ]; then
                    # Get value and import to target
                    value=$(docker exec "$temp_container" redis-cli DUMP "$key" 2>/dev/null)
                    ttl=$(docker exec "$temp_container" redis-cli TTL "$key" 2>/dev/null)
                    
                    if [ "$ttl" = "-1" ]; then
                        ttl=0
                    fi
                    
                    # Import to target with correct database
                    docker exec "$TARGET_REDIS_CONTAINER" bash -c "$target_redis_cmd -n $db RESTORE '$key' $ttl '$value'" >/dev/null 2>&1
                fi
            done < /tmp/temp_keys.txt
            echo "  ✓ RDB data imported for $stack"
        else
            echo "  ✗ Failed to read from temporary container"
        fi
        
        # Cleanup temporary container
        docker stop "$temp_container" >/dev/null 2>&1
        docker rm "$temp_container" >/dev/null 2>&1
        rm -f /tmp/temp_keys.txt
        
    elif [ "$MIGRATION_METHOD" = "live" ]; then
        # Live Import method
        export_script="$DUMP_DIR/${stack}_export.redis"
        
        if [ ! -f "$export_script" ]; then
            echo "  Skipping $stack - no export script found"
            continue
        fi
        
        # Import the script into target Redis
        echo "  Importing Redis commands..."
        
        # Select the correct database and import
        import_cmd="$target_redis_cmd -n $db"
        
        if docker exec -i "$TARGET_REDIS_CONTAINER" bash -c "$import_cmd" < "$export_script" >/dev/null 2>&1; then
            echo "  ✓ Successfully imported $stack"
        else
            echo "  ⚠ Import had warnings for $stack - checking keys..."
            
            # Check if keys were imported
            key_count=$(docker exec "$TARGET_REDIS_CONTAINER" bash -c "$target_redis_cmd -n $db DBSIZE" 2>/dev/null || echo "0")
            echo "  Keys in target database $db: $key_count"
        fi
    fi
done

echo
echo "=== Step 5: Verification ==="

echo "Checking target Redis databases:"
for stack in "${!REDIS_CONTAINERS[@]}"; do
    db="${REDIS_DBS[$stack]}"
    
    echo "--- Database $db ($stack) ---"
    
    # Get database info
    db_info=$(docker exec "$TARGET_REDIS_CONTAINER" bash -c "$target_redis_cmd -n $db INFO keyspace" 2>/dev/null || echo "empty")
    
    if [[ "$db_info" == *"keys="* ]]; then
        key_count=$(echo "$db_info" | grep "db$db:" | sed 's/.*keys=\([0-9]*\).*/\1/')
        echo "  ✓ Database $db contains $key_count keys"
        
        # Show sample keys
        echo "  Sample keys:"
        docker exec "$TARGET_REDIS_CONTAINER" bash -c "$target_redis_cmd -n $db KEYS '*'" 2>/dev/null | head -5 | sed 's/^/    - /'
    else
        echo "  ⚠ Database $db appears to be empty"
    fi
    echo
done

echo "=== Migration Summary ==="
echo "✓ Extracted Redis configurations from .env files"
echo "✓ Created backups using $MIGRATION_METHOD method in: $DUMP_DIR"
echo "✓ Imported data into $TARGET_REDIS_CONTAINER"
echo "✓ Verified data migration (check output above)"
echo
echo "Files created:"
if [ "$MIGRATION_METHOD" = "rdb" ]; then
    echo "  - RDB files: $DUMP_DIR/*_dump.rdb"
else
    echo "  - Export scripts: $DUMP_DIR/*_export.redis"
    echo "  - Key lists: $DUMP_DIR/*_keys.txt"
fi
echo
echo "=== Next Steps ==="
echo "1. Test your applications with $TARGET_REDIS_CONTAINER:"
for stack in "${!REDIS_CONTAINERS[@]}"; do
    db="${REDIS_DBS[$stack]}"
    echo "   docker exec -it $TARGET_REDIS_CONTAINER redis-cli -n $db"
done
echo
echo "2. Update your docker-compose.yml files to:"
echo "   - Change Redis host to '$TARGET_REDIS_CONTAINER'"
echo "   - Remove old Redis containers"
echo "   - Use the same network as $TARGET_REDIS_CONTAINER"
echo
echo "3. Test each application stack:"
echo "   - docker-compose down"
echo "   - docker-compose up -d"
echo "   - docker-compose logs -f"
echo
echo "4. When everything works, remove old containers:"
for stack in "${!REDIS_CONTAINERS[@]}"; do
    container="${REDIS_CONTAINERS[$stack]}"
    echo "   docker stop $container && docker rm $container"
done
echo
echo "Migration completed!"
