#!/usr/bin/env bats

setup() {
  export TEST_DIR="$BATS_TMPDIR/admin_menu_test"
  mkdir -p "$TEST_DIR"
  export TEMP_PASSWD="$TEST_DIR/passwd"
  cat << 'EOF' > "$TEMP_PASSWD"
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
alice:x:1000:1000:Alice:/home/alice:/bin/bash
bob:x:1001:1001:Bob:/home/bob:/bin/bash
EOF

  source "$BATS_TEST_DIRNAME/adminMenu.sh"

  # Override interactive/delay commands for fast testing
  pause() { :; }
  sleep() { :; }
  clear() { :; }
  export -f pause sleep clear

  grep() {
    local args=()
    for arg in "$@"; do
      if [[ "$arg" == "/etc/passwd" ]]; then
        args+=("$TEMP_PASSWD")
      else
        args+=("$arg")
      fi
    done
    command grep "${args[@]}"
  }
  export -f grep
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "show_menus displays the admin menu options" {
  run show_menus
  [ "$status" -eq 0 ]
  [[ "$output" == *"A D M I N - M E N U"* ]]
  [[ "$output" == *"1. List Admin Account"* ]]
  [[ "$output" == *"2. Create Admin Account"* ]]
  [[ "$output" == *"3. Delete Admin Account"* ]]
  [[ "$output" == *"4. Exit"* ]]
}

@test "one() lists regular user accounts within UID range" {
  getent() {
    if [[ "$1" == "passwd" ]]; then
      cat "$TEMP_PASSWD"
    fi
  }
  export -f getent

  run one
  [ "$status" -eq 0 ]
  [[ "$output" == *"alice"* ]]
  [[ "$output" == *"bob"* ]]
  [[ "$output" != *"root"* ]]
  [[ "$output" != *"daemon"* ]]
}

@test "two() rejects non-root users" {
  id() { echo "1000"; }
  export -f id

  run two <<< $'charlie\nsecret'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Only admins may add a user to the system."* ]]
}

@test "two() detects existing user with exact username match" {
  id() { echo "0"; }
  export -f id

  run two <<< $'alice\nsecret'
  [ "$status" -eq 0 ]
  [[ "$output" == *"alice already exist!"* ]]
}

@test "two() creates a new admin user when prefix matches an existing user" {
  id() { echo "0"; }
  useradd() { echo "MOCK_USERADD $*"; return 0; }
  usermod() { echo "MOCK_USERMOD $*"; return 0; }
  export -f id useradd usermod

  # 'al' is a prefix of 'alice', but not an existing user
  run two <<< $'al\nsecret'
  [ "$status" -eq 0 ]
  [[ "$output" == *"MOCK_USERADD"* ]]
  [[ "$output" == *"al has been added to system as admin!"* ]]
}

@test "two() reports failure when usermod fails" {
  id() { echo "0"; }
  useradd() { return 0; }
  usermod() { return 1; }
  export -f id useradd usermod

  run two <<< $'charlie\nsecret'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Failed to add a user!"* ]]
}

@test "three() rejects non-root users" {
  id() { echo "1000"; }
  export -f id

  run three <<< "alice"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Only admins may delete a user."* ]]
}

@test "three() reports error when user does not exist" {
  id() { echo "0"; }
  export -f id

  run three <<< "nonexistent"
  [ "$status" -eq 0 ]
  [[ "$output" == *"nonexistent does not exist!"* ]]
}

@test "three() deletes an existing user when run as root" {
  id() { echo "0"; }
  userdel() { echo "MOCK_USERDEL $*"; return 0; }
  export -f id userdel

  run three <<< "alice"
  [ "$status" -eq 0 ]
  [[ "$output" == *"MOCK_USERDEL -r alice"* ]]
  [[ "$output" == *"alice has been deleted!"* ]]
}

@test "read_options handles exit and invalid choices" {
  run read_options <<< "4"
  [ "$status" -eq 0 ]

  run read_options <<< "99"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Error..."* ]]
}
