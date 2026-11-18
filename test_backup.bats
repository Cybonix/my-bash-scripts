#!/usr/bin/env bats

setup() {
  export TEST_DIR="$BATS_TMPDIR/backup_test_dir"
  mkdir -p "$TEST_DIR"
  export TEST_FILE="$TEST_DIR/testfile.txt"
  echo "content" > "$TEST_FILE"
  unset BACKUP_SOURCE BACKUP_DEST
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "backup.sh (sourced) creates in-place .bak copy when only a file is provided" {
  source "$BATS_TEST_DIRNAME/backup.sh"

  date() {
    echo "2023-10-26.1200.bak"
  }
  export -f date

  run backup "$TEST_FILE"

  [ "$status" -eq 0 ]
  [ -f "${TEST_FILE}.2023-10-26.1200.bak" ]
  run cat "${TEST_FILE}.2023-10-26.1200.bak"
  [ "$output" = "content" ]
}

@test "backup.sh (executed directly) creates in-place .bak copy when only a file is provided" {
  date() {
    echo "2023-10-26.1200.bak"
  }
  export -f date

  run bash "$BATS_TEST_DIRNAME/backup.sh" "$TEST_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Backed up $TEST_FILE to ${TEST_FILE}.2023-10-26.1200.bak."* ]]
  [ -f "${TEST_FILE}.2023-10-26.1200.bak" ]
}

@test "backup.sh fails on in-place backup of a directory without destination" {
  run bash "$BATS_TEST_DIRNAME/backup.sh" "$TEST_DIR"
  [ "$status" -eq 1 ]
  [[ "$output" == *"is a directory. Please specify a destination directory"* ]]
}

@test "backup.sh fails on missing file in single-argument mode" {
  source "$BATS_TEST_DIRNAME/backup.sh"
  run backup "$TEST_DIR/nonexistent.txt"
  [ "$status" -eq 1 ]
  [[ "$output" == *"does not exist"* ]]
}

@test "backup.sh correctly creates tarball when destination directory is provided" {
  export BACKUP_SOURCE="$TEST_FILE"
  export BACKUP_DEST="$TEST_DIR"

  date() {
    echo "2023-10-26.1200"
  }
  hostname() {
    echo "testhost"
  }
  export -f date
  export -f hostname

  run bash "$BATS_TEST_DIRNAME/backup.sh" "$BACKUP_SOURCE" "$BACKUP_DEST"
  [ "$status" -eq 0 ]
  [ -f "$TEST_DIR/testhost-2023-10-26.1200.tar.gz" ]
}

@test "backup.sh fails on missing source in tarball mode" {
  run bash "$BATS_TEST_DIRNAME/backup.sh" "$TEST_DIR/nonexistent.txt" "$TEST_DIR"
  [ "$status" -eq 1 ]
  [[ "$output" == *"does not exist"* ]]
}

@test "backup.sh fails on missing destination directory" {
  run bash "$BATS_TEST_DIRNAME/backup.sh" "$TEST_FILE" "$TEST_DIR/nonexistent_dir"
  [ "$status" -eq 1 ]
  [[ "$output" == *"does not exist"* ]]
}

@test "backup.sh fails when no arguments or environment variables are provided" {
  run bash "$BATS_TEST_DIRNAME/backup.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
}