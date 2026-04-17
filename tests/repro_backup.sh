#!/bin/bash

# Source the backup function
source ./backup

# Create a test file
test_file="test_file.txt"
echo "This is a test file." > "$test_file"

echo "Attempting to backup $test_file..."
backup "$test_file"

if [ $? -eq 0 ]; then
    echo "Backup function returned 0"
else
    echo "Backup function failed with exit code $?"
fi

# Check if backup exists
# Expected newname format: test_file.txt.YYYY-MM-DD.HHMM.bak
backup_file=$(ls test_file.txt.*.bak 2>/dev/null)

if [ -n "$backup_file" ]; then
    echo "Backup file created: $backup_file"
else
    echo "FAILED: Backup file not created"
fi

# Clean up
rm -f "$test_file" "$backup_file"
