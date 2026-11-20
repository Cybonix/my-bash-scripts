# Linux System Administration Scripts

This repository contains a collection of bash scripts for Linux system administration. These scripts are designed to simplify common tasks such as user management, backups, system monitoring, and cleanup.

## Scripts

Here is a list of the scripts available in this repository:

### `adminMenu.sh`

A menu-driven shell script for managing administrative accounts on a Linux system.

**Features:**
- List administrative accounts belonging to the system's `wheel` and `sudo` groups.
- Add a new admin user with POSIX username validation, secure password assignment via `chpasswd`, and automatic assignment to the administrative group (`wheel` or `sudo`).
- Remove an existing user and their home directory with confirmation and a guard preventing deletion of `root`.

**Usage:**
```bash
chmod +x adminMenu.sh
sudo ./adminMenu.sh
```

### `backup.sh`

A unified backup script and shell function that supports both quick in-place file backups and compressed `.tar.gz` archive backups.

**Features:**
- **In-Place File Backup:** When given only a source file, creates a timestamped copy in the same directory (`<filename>.YYYY-MM-DD.HHMMSS.bak`) while preserving file attributes (`cp -p`) without overwriting existing backups.
- **Tarball Archive Backup:** When given both a source file/directory and a destination directory, creates a compressed archive named `<hostname>-<source>-YYYY-MM-DD.HHMMSS.tar.gz` inside the destination directory with relative paths, overwrite protection, and self-inclusion prevention.
- **Flexible Invocation:** Can be executed directly as `./backup.sh`, sourced in your shell (`source ./backup.sh && backup ...`), or configured via `BACKUP_SOURCE` and `BACKUP_DEST` environment variables.

**Usage:**
```bash
chmod +x backup.sh

# 1. In-place file backup (<file>.YYYY-MM-DD.HHMMSS.bak)
./backup.sh /path/to/file.conf

# 2. Compressed tarball archive in a destination directory
./backup.sh /path/to/source /path/to/destination_dir

# 3. Using environment variables
BACKUP_SOURCE=/path/to/source BACKUP_DEST=/path/to/destination_dir ./backup.sh

# 4. Sourced as a shell function
source ./backup.sh
backup /path/to/file.conf
```

### `wdw.sh` ("Who's Doing What")

A script to monitor user activity on the system. It shows who is currently logged in and provides information about their recent activity.

**Features:**
- Lists currently logged-in users (`who -u`) and the duration of their session.
- Shows historical logins (`last -F`) with full timestamps.
- Displays recent file and directory commands executed by each real user from their `.bash_history` (deduplicated across repeated login sessions).

**Usage:**
```bash
chmod +x wdw.sh
sudo ./wdw.sh
```

### `sys-cleaner/`

A utility to help you find and remove unused files and applications from your Ubuntu/Debian system.

**Features:**
- **Find Old Files:** Scans for files that haven't been accessed in a configurable number of days.
- **Scan Applications:** Lists manually installed packages from APT, Snap, and Flatpak.
- **Safe by Design:** Does not delete anything automatically. Instead, it generates an executable, shell-escaped removal script for you to review and run manually.
- **Interactive UI:** Uses `dialog` for a user-friendly TUI menu if installed, with an automatic fallback to a standard text menu.

**Usage:**
Navigate to the `sys-cleaner` directory and run the script:
```bash
cd sys-cleaner
chmod +x cleaner.sh
./cleaner.sh
```
For more details, please refer to [`sys-cleaner/README.md`](sys-cleaner/README.md).

## Testing & Linting

This repository uses [Bats (Bash Automated Testing System)](https://github.com/bats-core/bats-core) for unit tests and [ShellCheck](https://www.shellcheck.net/) for static analysis.

Run all tests and checks locally:
```bash
# Run ShellCheck
shellcheck adminMenu.sh backup.sh wdw.sh sys-cleaner/cleaner.sh sys-cleaner/tests/test_cleaner.sh

# Run Bats test suites
bats test_*.bats

# Run sys-cleaner standalone tests
bash sys-cleaner/tests/test_cleaner.sh
```

## General Usage

To run any of these scripts, make sure they are executable:
```bash
chmod +x <script_name>.sh
```
Some scripts require root privileges (`adminMenu.sh`, `wdw.sh`). Use `sudo` to execute them.

## Contributions

Contributions are welcome! If you have a script that you think would be a good addition to this collection, feel free to open a pull request.
