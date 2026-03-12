#!/bin/bash
# Script to validate that all keys in .example files exist in the actual .env files

EXIT_CODE=0

for example_file in *.example; do
    # Remove .example suffix to get the actual env file name
    env_file="${example_file%.example}"
    
    if [ ! -f "$env_file" ]; then
        echo "Error: Required env file '$env_file' is missing (based on $example_file)."
        EXIT_CODE=1
        continue
    fi

    echo "Validating $env_file against $example_file..."
    
    # Get all keys from the example file (lines that start with a word followed by =)
    # Also handles commented out variables in .example files
    keys=$(grep -E '^[A-Z0-9_]+=' "$example_file" | cut -d'=' -f1)
    # Also check for commented keys that might be mandatory
    commented_keys=$(grep -E '^# [A-Z0-9_]+=' "$example_file" | cut -d' ' -f2 | cut -d'=' -f1)
    
    for key in $keys $commented_keys; do
        if ! grep -q "^$key=" "$env_file"; then
            echo "  [FAIL] Missing key: $key"
            EXIT_CODE=1
        fi
    done
done

if [ $EXIT_CODE -eq 0 ]; then
    echo "All environment files are consistent with templates."
else
    echo "Environment validation failed!"
fi

exit $EXIT_CODE
