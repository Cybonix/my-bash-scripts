#!/bin/bash

# Test suite for cleaner.sh

# Source the script to test
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$DIR/../cleaner.sh"

test_scan_for_old_files_invalid_path() {
    echo "Testing scan_for_old_files with non-existent path..."

    local invalid_path="/tmp/this/path/does/not/exist/at/all/$(date +%s)"

    # scan_for_old_files reads 3 inputs:
    # 1. days_old
    # 2. scan_path
    # 3. excludes

    # We provide:
    # \n (empty for days_old default)
    # $invalid_path (for scan_path)
    # \n (empty for excludes default)

    output=$(printf "\n${invalid_path}\n\n" | scan_for_old_files 2>&1)
    exit_code=$?

    if [ $exit_code -ne 1 ]; then
        echo "❌ FAILED: Expected exit code 1, got $exit_code"
        return 1
    fi

    # The output contains color codes, so we use wildcard matching
    if [[ "$output" == *"[ERROR] The path '$invalid_path' does not exist or is not a directory."* ]]; then
        echo "✅ PASSED"
        return 0
    else
        echo "❌ FAILED: Error message not found in output."
        echo "Output was: $output"
        return 1
    fi
}

# Run tests
failed=0
test_scan_for_old_files_invalid_path || failed=1

if [ $failed -eq 0 ]; then
    echo "All tests passed!"
    exit 0
else
    echo "Some tests failed!"
    exit 1
fi
