#!/usr/bin/env bats

setup() {
  export TEST_DIR="$BATS_TMPDIR/wdw_test"
  mkdir -p "$TEST_DIR/home/alice"
  cat << 'EOF' > "$TEST_DIR/home/alice/.bash_history"
ls -la
cd /var/log
cat syslog
echo "hello"
rm -rf /tmp/old
vim notes.txt
touch newfile.txt
EOF

  source "$BATS_TEST_DIRNAME/wdw.sh"

  getent() {
    if [[ "$1" == "passwd" && -z "$2" ]]; then
      echo "root:x:0:0:root:/root:/bin/bash"
      echo "daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin"
      echo "alice:x:1000:1000:Alice:$TEST_DIR/home/alice:/bin/bash"
    elif [[ "$1" == "passwd" && "$2" == "alice" ]]; then
      echo "alice:x:1000:1000:Alice:$TEST_DIR/home/alice:/bin/bash"
    elif [[ "$1" == "passwd" && "$2" == "root" ]]; then
      echo "root:x:0:0:root:$TEST_DIR/root:/bin/bash"
    fi
  }
  export -f getent
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "wdw.sh exits with error when not run as root" {
  if [[ $EUID -eq 0 ]]; then
    skip "Running as root"
  fi
  run bash "$BATS_TEST_DIRNAME/wdw.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"This script must be run as root"* ]]
}

@test "get_real_users populates real_users array with UID >= 1000 and root" {
  get_real_users
  [[ " ${real_users[*]} " == *" alice "* ]]
  [[ " ${real_users[*]} " == *" root "* ]]
  [[ " ${real_users[*]} " != *" daemon "* ]]
}

@test "process_login formats current login with duration and extracts matching history commands" {
  real_users=(alice root)
  date() {
    if [[ "$1" == "--date="* ]]; then
      echo "1700000000"
    elif [[ "$1" == "+%s" ]]; then
      echo "1700003665"
    else
      command date "$@"
    fi
  }
  export -f date

  run process_login "alice pts/0 2023-11-14 22:13 00:05 2023-11-14 22:13:20" 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"alice - Logged in at: 2023-11-14 22:13:20 - Logged in for: 1h 1m 5s"* ]]
  [[ "$output" == *"|-- cd /var/log"* ]]
  [[ "$output" == *"|-- cat syslog"* ]]
  [[ "$output" == *"|-- rm -rf /tmp/old"* ]]
  [[ "$output" == *"|-- touch newfile.txt"* ]]
  [[ "$output" != *"echo \"hello\""* ]]
}

@test "process_login formats historical login without duration" {
  real_users=(alice root)

  run process_login "alice pts/0 192.168.1.10 Tue Nov 14 22:13:20 2023 - Tue Nov 14 23:00:00 2023" 0
  [ "$status" -eq 0 ]
  [[ "$output" == *"alice - Logged in at: 14 22:13:20 2023 - Tue Nov 14 23:00:00 2023"* ]]
  [[ "$output" != *"Logged in for:"* ]]
}

@test "process_login ignores system users not in real_users" {
  real_users=(alice root)

  run process_login "daemon pts/0 2023-11-14 22:13 00:05 2023-11-14 22:13:20" 1
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
