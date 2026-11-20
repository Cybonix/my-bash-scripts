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

  getent() {
    if [[ "$1" == "passwd" ]]; then
      if [[ -z "${2:-}" ]]; then
        cat "$TEMP_PASSWD"
      else
        awk -F: -v u="$2" '$1 == u {found=1; print} END {exit !found}' "$TEMP_PASSWD"
      fi
    elif [[ "$1" == "group" ]]; then
      case "${2:-}" in
        sudo) echo "sudo:x:27:alice,bob" ;;
        wheel) return 2 ;;
        *) return 2 ;;
      esac
    fi
  }
  export -f getent
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "show_menus displays the admin menu options" {
  run show_menus
  [ "$status" -eq 0 ]
  [[ "$output" == *"A D M I N - M E N U"* ]]
  [[ "$output" == *"1. List Admin Accounts"* ]]
  [[ "$output" == *"2. Create Admin Account"* ]]
  [[ "$output" == *"3. Delete Admin Account"* ]]
  [[ "$output" == *"4. Exit"* ]]
}

@test "one() lists admin accounts from wheel/sudo groups without duplicates" {
  getent() {
    if [[ "$1" == "group" && "$2" == "wheel" ]]; then
      echo "wheel:x:10:alice"
    elif [[ "$1" == "group" && "$2" == "sudo" ]]; then
      echo "sudo:x:27:alice,bob"
    else
      return 2
    fi
  }
  export -f getent

  run one
  [ "$status" -eq 0 ]
  [[ "$output" == *"alice (wheel)"* ]]
  [[ "$output" == *"bob (sudo)"* ]]
  # alice should only appear once
  local alice_count
  alice_count=$(echo "$output" | grep -c "alice")
  [ "$alice_count" -eq 1 ]
}

@test "one() reports when no admin accounts exist" {
  getent() { return 2; }
  export -f getent

  run one
  [ "$status" -eq 0 ]
  [[ "$output" == *"No admin accounts found"* ]]
}

@test "two() rejects non-root users" {
  id() { echo "1000"; }
  export -f id

  run two <<< $'charlie\nsecret'
  [ "$status" -eq 1 ]
  [[ "$output" == *"Only admins may add a user to the system."* ]]
}

@test "two() rejects empty username" {
  id() { echo "0"; }
  export -f id

  run two <<< $'\nsecret'
  [ "$status" -eq 1 ]
  [[ "$output" == *"Username cannot be empty!"* ]]
}

@test "two() rejects invalid or regex-metacharacter usernames" {
  id() { echo "0"; }
  export -f id

  run two <<< $'.*\nsecret'
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid username '.*'!"* ]]

  run two <<< $'root|alice\nsecret'
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid username 'root|alice'!"* ]]
}

@test "two() rejects empty password" {
  id() { echo "0"; }
  export -f id

  run two <<< $'charlie\n'
  [ "$status" -eq 1 ]
  [[ "$output" == *"Password cannot be empty!"* ]]
}

@test "two() detects existing user with exact username match" {
  id() { echo "0"; }
  export -f id

  run two <<< $'alice\nsecret'
  [ "$status" -eq 1 ]
  [[ "$output" == *"alice already exists!"* ]]
}

@test "two() creates a new admin user via useradd -G and chpasswd stdin" {
  id() { echo "0"; }
  useradd() { echo "MOCK_USERADD $*"; return 0; }
  chpasswd() {
    local line
    read -r line
    echo "MOCK_CHPASSWD_STDIN:$line"
    return 0
  }
  export -f id useradd chpasswd

  # 'al' is a prefix of 'alice', but not an existing user
  run two <<< $'al\nmysecretpass'
  [ "$status" -eq 0 ]
  [[ "$output" == *"MOCK_USERADD -m -G sudo al"* ]]
  [[ "$output" == *"MOCK_CHPASSWD_STDIN:al:mysecretpass"* ]]
  [[ "$output" == *"al has been added to system as admin (sudo)!"* ]]
}

@test "two() fails cleanly when no wheel or sudo group exists" {
  id() { echo "0"; }
  getent() {
    if [[ "$1" == "passwd" ]]; then
      return 2
    fi
    return 2
  }
  export -f id getent

  run two <<< $'charlie\nsecret'
  [ "$status" -eq 1 ]
  [[ "$output" == *"No admin group (wheel or sudo) found!"* ]]
}

@test "two() rolls back user creation when chpasswd fails" {
  id() { echo "0"; }
  useradd() { echo "MOCK_USERADD $*"; return 0; }
  chpasswd() { return 1; }
  userdel() { echo "MOCK_ROLLBACK_USERDEL $*" > "$TEST_DIR/rollback.log"; return 0; }
  export -f id useradd chpasswd userdel

  run two <<< $'charlie\nsecret'
  [ "$status" -eq 1 ]
  [ -f "$TEST_DIR/rollback.log" ]
  [[ "$(cat "$TEST_DIR/rollback.log")" == "MOCK_ROLLBACK_USERDEL -r charlie" ]]
  [[ "$output" == *"user creation rolled back"* ]]
}

@test "three() rejects non-root users" {
  id() { echo "1000"; }
  export -f id

  run three <<< "alice"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Only admins may delete a user."* ]]
}

@test "three() refuses to delete root account" {
  id() { echo "0"; }
  export -f id

  run three <<< "root"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Refusing to delete the root account!"* ]]
}

@test "three() rejects invalid/regex usernames" {
  id() { echo "0"; }
  export -f id

  run three <<< ".*"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid username '.*'!"* ]]
}

@test "three() reports error when user does not exist" {
  id() { echo "0"; }
  export -f id

  run three <<< "nonexistent"
  [ "$status" -eq 1 ]
  [[ "$output" == *"nonexistent does not exist!"* ]]
}

@test "three() cancels deletion unless user confirms with y" {
  id() { echo "0"; }
  userdel() { echo "SHOULD_NOT_RUN"; return 0; }
  export -f id userdel

  run three <<< $'alice\nn'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Deletion cancelled."* ]]
  [[ "$output" != *"SHOULD_NOT_RUN"* ]]
}

@test "three() deletes an existing user when confirmed as root" {
  id() { echo "0"; }
  userdel() { echo "MOCK_USERDEL $*"; return 0; }
  export -f id userdel

  run three <<< $'alice\ny'
  [ "$status" -eq 0 ]
  [[ "$output" == *"MOCK_USERDEL -r alice"* ]]
  [[ "$output" == *"alice has been deleted!"* ]]
}

@test "three() reports error when userdel fails" {
  id() { echo "0"; }
  userdel() { return 1; }
  export -f id userdel

  run three <<< $'alice\ny'
  [ "$status" -eq 1 ]
  [[ "$output" == *"Failed to delete 'alice'!"* ]]
}

@test "read_options handles exit and invalid choices" {
  run read_options <<< "4"
  [ "$status" -eq 0 ]

  run read_options <<< "99"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Error..."* ]]
}
