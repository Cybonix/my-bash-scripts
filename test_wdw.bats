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
    if [[ "$1" == "passwd" && -z "${2:-}" ]]; then
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

@test "get_real_users populates real_users array with UID >= UID_MIN and root" {
  get_real_users
  [[ " ${real_users[*]} " == *" alice "* ]]
  [[ " ${real_users[*]} " == *" root "* ]]
  [[ " ${real_users[*]} " != *" daemon "* ]]
}

@test "process_login parses realistic ISO who -u output with duration and extracts history including vim" {
  real_users=(alice root)
  seen_history=()
  date() {
    if [[ "$1" == "--date=2023-11-14 22:13" ]]; then
      echo "1700000000"
    elif [[ "$1" == "+%s" ]]; then
      echo "1700003665"
    else
      command date "$@"
    fi
  }
  export -f date

  run process_login "alice    pts/0        2023-11-14 22:13 00:05       12345 (192.168.1.10)" 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"alice - Logged in at: 2023-11-14 22:13 - Logged in for: 1h 1m 5s"* ]]
  [[ "$output" == *"|-- cd /var/log"* ]]
  [[ "$output" == *"|-- cat syslog"* ]]
  [[ "$output" == *"|-- rm -rf /tmp/old"* ]]
  [[ "$output" == *"|-- vim notes.txt"* ]]
  [[ "$output" == *"|-- touch newfile.txt"* ]]
  [[ "$output" != *"echo \"hello\""* ]]
}

@test "process_login parses traditional POSIX who -u output" {
  real_users=(alice root)
  seen_history=()
  date() {
    if [[ "$1" == "--date=Nov 14 22:13" ]]; then
      echo "1700000000"
    elif [[ "$1" == "+%s" ]]; then
      echo "1700000125"
    else
      command date "$@"
    fi
  }
  export -f date

  run process_login "alice    pts/0        Nov 14 22:13   .         12345 (192.168.1.10)" 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"alice - Logged in at: Nov 14 22:13 - Logged in for: 0h 2m 5s"* ]]
}

@test "process_login falls back gracefully when login timestamp cannot be parsed" {
  real_users=(alice root)
  seen_history=()
  date() {
    if [[ "$1" == "--date="* ]]; then
      return 1
    elif [[ "$1" == "+%s" ]]; then
      echo "1700000125"
    else
      command date "$@"
    fi
  }
  export -f date

  run process_login "alice    pts/0        invalid-date 00:05 12345" 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"Logged in for: unknown"* ]]
}

@test "process_login preserves full timestamp for last -F (remote host and local tty)" {
  real_users=(alice root)
  seen_history=()

  run process_login "alice    pts/0        192.168.1.10     Tue Nov 14 22:13:20 2023 - Tue Nov 14 23:00:00 2023  (00:46)" 0
  [ "$status" -eq 0 ]
  [[ "$output" == *"alice - Logged in at: Tue Nov 14 22:13:20 2023 - Tue Nov 14 23:00:00 2023  (00:46)"* ]]
  [[ "$output" != *"Logged in for:"* ]]

  seen_history=()
  run process_login "alice    tty1                          Tue Nov  4 09:05:00 2023 - Tue Nov  4 10:00:00 2023  (00:55)" 0
  [ "$status" -eq 0 ]
  [[ "$output" == *"alice - Logged in at: Tue Nov  4 09:05:00 2023 - Tue Nov  4 10:00:00 2023  (00:55)"* ]]
}

@test "process_login prints user bash history only once across repeated sessions" {
  real_users=(alice root)
  seen_history=()

  run bash -c '
    source "$1"
    real_users=(alice root)
    seen_history=()
    getent() {
      echo "alice:x:1000:1000:Alice:$TEST_DIR/home/alice:/bin/bash"
    }
    process_login "alice    pts/0        192.168.1.10     Tue Nov 14 22:13:20 2023 - Tue Nov 14 23:00:00 2023  (00:46)" 0
    process_login "alice    pts/1        192.168.1.10     Mon Nov 13 10:00:00 2023 - Mon Nov 13 11:00:00 2023  (01:00)" 0
  ' _ "$BATS_TEST_DIRNAME/wdw.sh"
  [ "$status" -eq 0 ]
  local cd_count
  cd_count=$(echo "$output" | grep -c "|-- cd /var/log")
  [ "$cd_count" -eq 1 ]
}

@test "process_login ignores system users and wtmp footer lines" {
  real_users=(alice root)
  seen_history=()

  run process_login "daemon   pts/0        2023-11-14 22:13 00:05       12345 (192.168.1.10)" 1
  [ "$status" -eq 0 ]
  [ -z "$output" ]

  run process_login "wtmp begins Mon Nov  1 00:00:00 2023" 0
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
