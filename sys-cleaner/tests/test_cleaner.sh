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

test_generate_removal_script() {
    echo "Testing generate_removal_script..."
    local local_failed=0

    # Mock date to have a predictable filename
    date() {
        if [[ "$*" == "+%Y%m%d_%H%M%S" ]]; then
            echo "20231027_120000"
        else
            command date "$@"
        fi
    }
    export -f date

    local expected_script="./remove_old_files_20231027_120000.sh"
    rm -f "$expected_script"

    local test_files=(
        "1698408000|1024|/tmp/testfile1.txt"
        "1698408000|2048|/tmp/testfile 2.txt"
    )

    generate_removal_script "${test_files[@]}" > /dev/null

    if [[ ! -f "$expected_script" ]]; then
        echo "❌ FAILED: Removal script not generated."
        unset -f date
        return 1
    fi

    # Check contents
    if ! grep -q "#!/bin/bash" "$expected_script"; then
        echo "❌ FAILED: Shebang missing."
        local_failed=1
    fi

    if ! grep -q "rm -v \"/tmp/testfile1.txt\"" "$expected_script"; then
        echo "❌ FAILED: Command for testfile1.txt missing or incorrect."
        local_failed=1
    fi

    if ! grep -q "rm -v \"/tmp/testfile 2.txt\"" "$expected_script"; then
        echo "❌ FAILED: Command for testfile 2.txt missing or incorrect (check quoting)."
        local_failed=1
    fi

    if ! grep -q "Total size of files to be removed: " "$expected_script"; then
        echo "❌ FAILED: Total size summary missing."
        local_failed=1
    fi

    # Verify that numfmt didn't fail (the script should contain the expected size)
    if ! grep -q "Size: 1.0KiB" "$expected_script"; then
        echo "❌ FAILED: Expected size '1.0KiB' not found in script."
        local_failed=1
    fi

    rm -f "$expected_script"
    unset -f date

    if [[ $local_failed -eq 1 ]]; then
        return 1
    else
        echo "✅ PASSED"
        return 0
    fi
}

# Run tests
failed=0
test_scan_for_old_files_invalid_path || failed=1
test_generate_removal_script || failed=1

if [ $failed -eq 0 ]; then
    echo "All tests passed!"
    exit 0
else
    echo "Some tests failed!"
    exit 1
fi
