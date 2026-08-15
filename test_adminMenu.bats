#!/usr/bin/env bats

setup() {
  # Create a mock /etc/passwd
  export TEMP_PASSWD="$BATS_TMPDIR/passwd"
  echo "root:x:0:0:root:/root:/bin/bash" > "$TEMP_PASSWD"
  echo "testuser:x:1000:1000::/home/testuser:/bin/bash" >> "$TEMP_PASSWD"

  # Mock functions
  grep() {
    command grep "$@"
  }
}

@test "dummy test" {
  [ 1 -eq 1 ]
}
