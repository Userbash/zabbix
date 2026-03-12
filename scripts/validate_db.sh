#!/bin/bash
# Script to validate Zabbix database schema integrity in PostgreSQL

DB_USER=$(cat .POSTGRES_USER)
DB_PASS=$(cat .POSTGRES_PASSWORD)
DB_NAME="zabbix" # Default name usually used in these setups

echo "Checking database schema..."

# Check if 'users' table exists as a proxy for schema health
TABLE_CHECK=$(docker exec postgres psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'users');" | tr -d '[:space:]')

if [ "$TABLE_CHECK" == "t" ]; then
    echo "  [SUCCESS] Database schema 'users' table exists."
    
    # Check row count in users table
    USER_COUNT=$(docker exec postgres psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT count(*) FROM users;" | tr -d '[:space:]')
    echo "  [INFO] Found $USER_COUNT users in the database."
    
    if [ "$USER_COUNT" -gt 0 ]; then
        echo "  [SUCCESS] Database is populated."
        exit 0
    else
        echo "  [FAIL] Database is empty."
        exit 1
    fi
else
    echo "  [FAIL] Database schema is not properly initialized."
    exit 1
fi
