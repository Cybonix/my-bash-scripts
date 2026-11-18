#!/usr/bin/env bats

setup() {
  export TEST_DIR="$BATS_TMPDIR/cleaner_test"
  mkdir -p "$TEST_DIR"
  cd "$TEST_DIR" || exit 1
  source "$BATS_TEST_DIRNAME/sys-cleaner/cleaner.sh"
  export USE_DIALOG=0

  date() {
    if [[ "$*" == "+%Y%m%d_%H%M%S" ]]; then
      echo "20231027_120000"
    else
      command date "$@"
    fi
  }
  export -f date
}

teardown() {
  cd "$BATS_TEST_DIRNAME" || true
  rm -rf "$TEST_DIR"
}

@test "scan_for_old_files fails on non-existent directory" {
  run scan_for_old_files <<< $'\n/tmp/nonexistent_cleaner_dir_12345\n\n'
  [ "$status" -eq 1 ]
  [[ "$output" == *"[ERROR] The path '/tmp/nonexistent_cleaner_dir_12345' does not exist or is not a directory."* ]]
}

@test "scan_for_old_files fails on invalid days input" {
  run scan_for_old_files <<< $'not_a_number\n'
  [ "$status" -eq 1 ]
  [[ "$output" == *"[ERROR] Invalid number of days: 'not_a_number'."* ]]
}

@test "generate_removal_script creates executable script with escaped paths and total size" {
  local test_files=(
    "1698408000|1024|/tmp/test file 1.txt"
    "1698408000|2048|/tmp/test_file_2.txt"
  )

  run generate_removal_script "${test_files[@]}"
  [ "$status" -eq 0 ]
  [ -x "./remove_old_files_20231027_120000.sh" ]

  run cat "./remove_old_files_20231027_120000.sh"
  [[ "$output" == *'rm -v /tmp/test\ file\ 1.txt # Size: 1.0KiB'* ]]
  [[ "$output" == *'rm -v /tmp/test_file_2.txt # Size: 2.0KiB'* ]]
  [[ "$output" == *'# Total size of files to be removed: 3.0KiB'* ]]
}

@test "generate_app_removal_script generates safe apt removal script" {
  run generate_app_removal_script "apt" "htop|102400|interactive process viewer" <<< "htop curl"
  [ "$status" -eq 0 ]
  [ -x "./remove_apt_packages_20231027_120000.sh" ]

  run cat "./remove_apt_packages_20231027_120000.sh"
  [[ "$output" == *"sudo apt-get purge htop curl"* ]]
  [[ "$output" == *"sudo apt-get autoremove"* ]]
}

@test "generate_app_removal_script generates safe snap removal script" {
  run generate_app_removal_script "snap" "vlc|300MB|-" <<< "vlc"
  [ "$status" -eq 0 ]
  [ -x "./remove_snap_packages_20231027_120000.sh" ]

  run cat "./remove_snap_packages_20231027_120000.sh"
  [[ "$output" == *"sudo snap remove vlc"* ]]
}

@test "generate_app_removal_script generates safe flatpak removal script" {
  run generate_app_removal_script "flatpak" "org.gimp.GIMP|" <<< "org.gimp.GIMP"
  [ "$status" -eq 0 ]
  [ -x "./remove_flatpak_packages_20231027_120000.sh" ]

  run cat "./remove_flatpak_packages_20231027_120000.sh"
  [[ "$output" == *"flatpak uninstall --delete-data org.gimp.GIMP"* ]]
}
