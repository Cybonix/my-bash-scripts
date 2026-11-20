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

@test "scan_for_old_files handles trailing slash, prunes nested excludes, and generates script" {
  local scan_root="$TEST_DIR/scan_root"
  mkdir -p "$scan_root/project/.git" "$scan_root/.local/share/Trash" "$scan_root/docs"

  # Create old files (200 days old) and a recent file
  printf '%s' "old document" > "$scan_root/docs/old.txt"
  printf '%s' "git object" > "$scan_root/project/.git/object"
  printf '%s' "trashed" > "$scan_root/.local/share/Trash/deleted.txt"
  printf '%s' "fresh" > "$scan_root/docs/recent.txt"

  touch -a -d "200 days ago" "$scan_root/docs/old.txt"
  touch -a -d "200 days ago" "$scan_root/project/.git/object"
  touch -a -d "200 days ago" "$scan_root/.local/share/Trash/deleted.txt"

  # Pass trailing slash on scan_root, default excludes, and 'y' to generate script
  run scan_for_old_files <<< "$(printf '180\n%s/\n\ny\n' "$scan_root")"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Found 1 old files."* ]]
  [[ "$output" == *"$scan_root/docs/old.txt"* ]]
  [[ "$output" != *".git/object"* ]]
  [[ "$output" != *"Trash/deleted.txt"* ]]
  [[ "$output" != *"recent.txt"* ]]

  [ -x "./remove_old_files_20231027_120000.sh" ]
  run cat "./remove_old_files_20231027_120000.sh"
  [[ "$output" == *"rm -v -- $scan_root/docs/old.txt"* ]]
}

@test "generate_removal_script safely escapes spaces, leading hyphens, and newlines" {
  local newline_path=$'/tmp/line1\nline2.txt'
  local test_files=(
    "1698408000|1024|/tmp/test file 1.txt"
    "1698408000|2048|-leading-dash.txt"
    "1698408000|512|${newline_path}"
  )

  run generate_removal_script "${test_files[@]}"
  [ "$status" -eq 0 ]
  [ -x "./remove_old_files_20231027_120000.sh" ]

  run cat "./remove_old_files_20231027_120000.sh"
  [[ "$output" == *'rm -v -- /tmp/test\ file\ 1.txt # Size: 1.0KiB'* ]]
  [[ "$output" == *'rm -v -- -leading-dash.txt # Size: 2.0KiB'* ]]
  [[ "$output" == *"rm -v -- \$'/tmp/line1\\nline2.txt' # Size: 512B"* ]]
  [[ "$output" == *'# Total size of files to be removed: 3.5KiB'* ]]
}

@test "scan_apt_packages batches dpkg-query into a single call and sorts by size" {
  local call_log="$TEST_DIR/dpkg_calls.log"
  apt-mark() {
    printf 'smallpkg\nbigpkg\n'
  }
  dpkg-query() {
    echo "CALLED" >> "$TEST_DIR/dpkg_calls.log"
    printf 'smallpkg|10|A small package\n'
    printf 'bigpkg|2048|A big package\n'
  }
  export -f apt-mark dpkg-query

  run scan_apt_packages <<< "n"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Found 2 manually installed packages."* ]]
  # Verify dpkg-query was only called once
  [ "$(wc -l < "$call_log")" -eq 1 ]
  # Verify bigpkg appears before smallpkg
  local big_line small_line
  big_line=$(echo "$output" | grep -n "bigpkg" | head -n1 | cut -d: -f1)
  small_line=$(echo "$output" | grep -n "smallpkg" | head -n1 | cut -d: -f1)
  [ "$big_line" -lt "$small_line" ]
}

@test "scan_snap_packages displays accurate Rev, Publisher, and Notes columns" {
  snap() {
    cat << 'EOF'
Name     Version  Rev   Tracking       Publisher   Notes
firefox  120.0    3416  latest/stable  mozilla**   -
core22   202311   1033  latest/stable  canonical*  base
EOF
  }
  export -f snap

  run scan_snap_packages <<< "n"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Package"* ]]
  [[ "$output" == *"Rev"* ]]
  [[ "$output" == *"Publisher"* ]]
  [[ "$output" == *"Notes"* ]]
  [[ "$output" == *"firefox"* ]]
  [[ "$output" == *"3416"* ]]
  [[ "$output" == *"mozilla**"* ]]
  [[ "$output" == *"core22"* ]]
  [[ "$output" == *"base"* ]]
}

@test "scan_flatpak_packages lists applications via --app and displays size" {
  flatpak() {
    if [[ "$*" == *"--app"* ]]; then
      printf 'org.gimp.GIMP\t450.2 MB\n'
      printf 'org.mozilla.firefox\t280.1 MB\n'
    fi
  }
  export -f flatpak

  run scan_flatpak_packages <<< "n"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Found 2 Flatpak applications."* ]]
  [[ "$output" == *"org.gimp.GIMP"* ]]
  [[ "$output" == *"450.2 MB"* ]]
  [[ "$output" == *"org.mozilla.firefox"* ]]
}

@test "generate_app_removal_script generates safe apt removal script" {
  run generate_app_removal_script "apt" "htop|102400|interactive process viewer" <<< "htop curl"
  [ "$status" -eq 0 ]
  [ -x "./remove_apt_packages_20231027_120000.sh" ]

  run cat "./remove_apt_packages_20231027_120000.sh"
  [[ "$output" == *"sudo apt-get purge -- htop curl"* ]]
  [[ "$output" == *"sudo apt-get autoremove"* ]]
}

@test "generate_app_removal_script generates safe snap removal script" {
  run generate_app_removal_script "snap" "vlc|3078|videolan|-" <<< "vlc"
  [ "$status" -eq 0 ]
  [ -x "./remove_snap_packages_20231027_120000.sh" ]

  run cat "./remove_snap_packages_20231027_120000.sh"
  [[ "$output" == *"sudo snap remove -- vlc"* ]]
}

@test "generate_app_removal_script generates safe flatpak removal script" {
  run generate_app_removal_script "flatpak" "org.gimp.GIMP|450MB|" <<< "org.gimp.GIMP"
  [ "$status" -eq 0 ]
  [ -x "./remove_flatpak_packages_20231027_120000.sh" ]

  run cat "./remove_flatpak_packages_20231027_120000.sh"
  [[ "$output" == *"flatpak uninstall --delete-data -- org.gimp.GIMP"* ]]
}

@test "main() text menu loops after an action until user exits" {
  scan_for_old_files() {
    echo "MOCK_SCAN_OLD_FILES"
  }
  export -f scan_for_old_files

  run main <<< $'1\n3\n'
  [ "$status" -eq 0 ]
  [[ "$output" == *"MOCK_SCAN_OLD_FILES"* ]]
  [[ "$output" == *"Exiting."* ]]
}
