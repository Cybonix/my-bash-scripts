#!/bin/bash
# shellcheck disable=SC1091,SC2317

# Test suite for cleaner.sh

# Source the script to test
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$DIR/../cleaner.sh"

test_scan_for_old_files_invalid_path() {
    echo "Testing scan_for_old_files with non-existent path..."

    local invalid_path
    invalid_path="/tmp/this/path/does/not/exist/at/all/$(date +%s)"

    # scan_for_old_files reads 3 inputs:
    # 1. days_old
    # 2. scan_path
    # 3. excludes

    output=$(printf '\n%s\n\n' "$invalid_path" | scan_for_old_files 2>&1)
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

test_scan_for_old_files_invalid_days() {
    echo "Testing scan_for_old_files with invalid days input..."

    output=$(printf 'abc\n' | scan_for_old_files 2>&1)
    exit_code=$?

    if [ $exit_code -ne 1 ]; then
        echo "❌ FAILED: Expected exit code 1, got $exit_code"
        return 1
    fi

    if [[ "$output" == *"[ERROR] Invalid number of days: 'abc'."* ]]; then
        echo "✅ PASSED"
        return 0
    else
        echo "❌ FAILED: Invalid days error message not found in output."
        echo "Output was: $output"
        return 1
    fi
}

test_generate_removal_script() {
    echo "Testing generate_removal_script..."

    # Mock date for predictable filename
    date() {
        if [[ "$*" == "+%Y%m%d_%H%M%S" ]]; then
            echo "20231027_120000"
        else
            command date "$@"
        fi
    }

    local expected_script="./remove_old_files_20231027_120000.sh"
    rm -f "$expected_script"

    local test_files=(
        "1698408000|1024|/tmp/test file 1.txt"
        "1698408000|2048|/tmp/test_file_2.txt"
    )

    generate_removal_script "${test_files[@]}" > /dev/null

    if [[ ! -f "$expected_script" ]]; then
        echo "❌ FAILED: Script $expected_script was not generated."
        unset -f date
        return 1
    fi

    # Check if files are correctly escaped and added once to the script
    if ! grep -qF 'rm -v -- /tmp/test\ file\ 1.txt' "$expected_script"; then
        echo "❌ FAILED: File 1 removal command not found or incorrect."
        rm -f "$expected_script"
        unset -f date
        return 1
    fi

    if ! grep -qF 'rm -v -- /tmp/test_file_2.txt' "$expected_script"; then
        echo "❌ FAILED: File 2 removal command not found or incorrect."
        rm -f "$expected_script"
        unset -f date
        return 1
    fi

    # Ensure no duplicate commands were written (2 files -> 2 rm commands)
    local rm_count
    rm_count=$(grep -c '^rm -v -- ' "$expected_script")
    if [[ "$rm_count" -ne 2 ]]; then
        echo "❌ FAILED: Expected 2 rm commands, found $rm_count"
        rm -f "$expected_script"
        unset -f date
        return 1
    fi

    # Check total size calculation (1024 + 2048 = 3072 -> 3.0KiB)
    if ! grep -q "Total size of files to be removed: 3.0KiB" "$expected_script"; then
        echo "❌ FAILED: Total size calculation missing or incorrect."
        rm -f "$expected_script"
        unset -f date
        return 1
    fi

    echo "✅ PASSED"
    rm -f "$expected_script"
    unset -f date
    return 0
}

# Run tests
failed=0
test_scan_for_old_files_invalid_path || failed=1
test_scan_for_old_files_invalid_days || failed=1
test_generate_removal_script || failed=1

if [ $failed -eq 0 ]; then
    echo "All tests passed!"
    exit 0
else
    echo "Some tests failed!"
    exit 1
fi
