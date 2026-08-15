#!/usr/bin/env bats

setup() {
  export TEST_DIR="$BATS_TMPDIR/backup_test_dir"
  mkdir -p "$TEST_DIR"
  export TEST_FILE="$TEST_DIR/testfile.txt"
  echo "content" > "$TEST_FILE"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "backup function correctly copies file" {
  source backup

  # Mock date
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

@test "backup function fails on missing file" {
  source backup
  run backup "$TEST_DIR/nonexistent.txt"
  [ "$status" -eq 1 ]
  [[ "$output" == *"does not exist"* ]]
}

@test "backup.sh correctly creates tarball" {
  export BACKUP_SOURCE="$TEST_FILE"
  export BACKUP_DEST="$TEST_DIR"

  # Mock date and hostname
  date() {
    echo "2023-10-26.1200"
  }
  hostname() {
    echo "testhost"
  }
  export -f date
  export -f hostname

  run bash backup.sh "$BACKUP_SOURCE" "$BACKUP_DEST"
  [ "$status" -eq 0 ]
  [ -f "$TEST_DIR/testhost-2023-10-26.1200.tar.gz" ]
}

@test "backup.sh fails on missing source" {
  run bash backup.sh "$TEST_DIR/nonexistent.txt" "$TEST_DIR"
  [ "$status" -eq 1 ]
  [[ "$output" == *"does not exist"* ]]
}

@test "backup.sh fails on missing dest" {
  run bash backup.sh "$TEST_FILE" "$TEST_DIR/nonexistent_dir"
  [ "$status" -eq 1 ]
  [[ "$output" == *"does not exist"* ]]
}

@test "backup.sh fails on missing arguments" {
  run bash backup.sh
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage"* ]]
}