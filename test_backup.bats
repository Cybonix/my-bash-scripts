#!/usr/bin/env bats

setup() {
  export TEST_DIR="$BATS_TMPDIR/backup_test_dir"
  mkdir -p "$TEST_DIR/src_dir" "$TEST_DIR/dest_dir"
  export TEST_FILE="$TEST_DIR/testfile.txt"
  echo "content" > "$TEST_FILE"
  echo "nested" > "$TEST_DIR/src_dir/nested.txt"
  unset BACKUP_SOURCE BACKUP_DEST
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "backup.sh (sourced) creates in-place .bak copy when only a file is provided" {
  source "$BATS_TEST_DIRNAME/backup.sh"

  date() {
    echo "2023-10-26.120005.bak"
  }
  export -f date

  run backup "$TEST_FILE"

  [ "$status" -eq 0 ]
  [ -f "${TEST_FILE}.2023-10-26.120005.bak" ]
  run cat "${TEST_FILE}.2023-10-26.120005.bak"
  [ "$output" = "content" ]
}

@test "backup.sh (executed directly) creates in-place .bak copy when only a file is provided" {
  date() {
    echo "2023-10-26.120005.bak"
  }
  export -f date

  run bash "$BATS_TEST_DIRNAME/backup.sh" "$TEST_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Backed up $TEST_FILE to ${TEST_FILE}.2023-10-26.120005.bak."* ]]
  [ -f "${TEST_FILE}.2023-10-26.120005.bak" ]
}

@test "backup.sh refuses to overwrite an existing in-place .bak copy" {
  date() {
    echo "2023-10-26.120005.bak"
  }
  export -f date

  touch "${TEST_FILE}.2023-10-26.120005.bak"

  run bash "$BATS_TEST_DIRNAME/backup.sh" "$TEST_FILE"
  [ "$status" -eq 1 ]
  [[ "$output" == *"already exists"* ]]
}

@test "backup.sh handles filenames starting with a hyphen" {
  local dash_file="$TEST_DIR/-weird.txt"
  echo "dash content" > "$dash_file"

  date() {
    echo "2023-10-26.120005"
  }
  hostname() {
    echo "testhost"
  }
  export -f date hostname

  # In-place backup (from inside TEST_DIR so argument literally starts with '-')
  run bash -c 'cd "$1" && "$2" "-weird.txt"' _ "$TEST_DIR" "$BATS_TEST_DIRNAME/backup.sh"
  [ "$status" -eq 0 ]
  [ -f "$TEST_DIR/-weird.txt.2023-10-26.120005.bak" ]

  # Tarball backup
  run bash "$BATS_TEST_DIRNAME/backup.sh" "$dash_file" "$TEST_DIR/dest_dir"
  [ "$status" -eq 0 ]
  [ -f "$TEST_DIR/dest_dir/testhost--weird.txt-2023-10-26.120005.tar.gz" ]
}

@test "backup.sh fails on in-place backup of a directory without destination" {
  run bash "$BATS_TEST_DIRNAME/backup.sh" "$TEST_DIR/src_dir"
  [ "$status" -eq 1 ]
  [[ "$output" == *"is a directory. Please specify a destination directory"* ]]
}

@test "backup.sh fails on missing file in single-argument mode" {
  source "$BATS_TEST_DIRNAME/backup.sh"
  run backup "$TEST_DIR/nonexistent.txt"
  [ "$status" -eq 1 ]
  [[ "$output" == *"does not exist"* ]]
}

@test "backup.sh creates tarball of a file with source basename and relative paths" {
  date() {
    echo "2023-10-26.120005"
  }
  hostname() {
    echo "testhost"
  }
  export -f date hostname

  run bash "$BATS_TEST_DIRNAME/backup.sh" "$TEST_FILE" "$TEST_DIR/dest_dir"
  [ "$status" -eq 0 ]
  local archive="$TEST_DIR/dest_dir/testhost-testfile.txt-2023-10-26.120005.tar.gz"
  [ -f "$archive" ]
  run tar -tzf "$archive"
  [ "$output" = "testfile.txt" ]
}

@test "backup.sh creates tarball of a directory using BACKUP_SOURCE and BACKUP_DEST env vars only" {
  export BACKUP_SOURCE="$TEST_DIR/src_dir"
  export BACKUP_DEST="$TEST_DIR/dest_dir"

  date() {
    echo "2023-10-26.120005"
  }
  hostname() {
    echo "testhost"
  }
  export -f date hostname

  run bash "$BATS_TEST_DIRNAME/backup.sh"
  [ "$status" -eq 0 ]
  local archive="$TEST_DIR/dest_dir/testhost-src_dir-2023-10-26.120005.tar.gz"
  [ -f "$archive" ]
  run tar -tzf "$archive"
  [[ "$output" == *"src_dir/nested.txt"* ]]
}

@test "backup.sh rejects tarball destination equal to or inside source directory" {
  mkdir -p "$TEST_DIR/src_dir/sub_dest"

  run bash "$BATS_TEST_DIRNAME/backup.sh" "$TEST_DIR/src_dir" "$TEST_DIR/src_dir"
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot be inside source directory"* ]]

  run bash "$BATS_TEST_DIRNAME/backup.sh" "$TEST_DIR/src_dir" "$TEST_DIR/src_dir/sub_dest"
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot be inside source directory"* ]]
}

@test "backup.sh refuses to overwrite an existing tarball archive" {
  date() {
    echo "2023-10-26.120005"
  }
  hostname() {
    echo "testhost"
  }
  export -f date hostname

  touch "$TEST_DIR/dest_dir/testhost-testfile.txt-2023-10-26.120005.tar.gz"

  run bash "$BATS_TEST_DIRNAME/backup.sh" "$TEST_FILE" "$TEST_DIR/dest_dir"
  [ "$status" -eq 1 ]
  [[ "$output" == *"already exists"* ]]
}

@test "backup.sh fails on missing source in tarball mode" {
  run bash "$BATS_TEST_DIRNAME/backup.sh" "$TEST_DIR/nonexistent.txt" "$TEST_DIR/dest_dir"
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