# Linux System Administration Scripts

This repository contains a collection of bash scripts for Linux system administration. These scripts are designed to simplify common tasks such as user management, backups, system monitoring, and cleanup.

## Scripts

Here is a list of the scripts available in this repository:

### `adminMenu.sh`

A menu-driven shell script for managing administrative accounts on a Linux system.

**Features:**
- List all regular user accounts within the system's configured `UID_MIN` and `UID_MAX` range.
- Add a new admin user with an encrypted password and assign them to the administrative group (`wheel` or `sudo`).
- Remove an existing admin user and their home directory.

**Usage:**
```bash
chmod +x adminMenu.sh
sudo ./adminMenu.sh
```

### `backup`

A lightweight Bash function (and standalone script) that backs up individual files in-place with a standardized timestamp suffix (`<filename>.YYYY-MM-DD.HHMM.bak`) while preserving file attributes.

**Usage:**
Source it in your shell or `.bashrc`:
```bash
source ./backup
backup /path/to/file.conf
```
Or execute it directly:
```bash
./backup /path/to/file.conf
```

### `backup.sh`

A script to create a compressed `.tar.gz` archive of a specified file or directory.

**Features:**
- Backs up a file or directory to a `.tar.gz` archive named `<hostname>-YYYY-MM-DD.HHMM.tar.gz`.
- Accepts command-line arguments or `BACKUP_SOURCE` and `BACKUP_DEST` environment variables.
- Validates source and destination paths before archiving.

**Usage:**
Pass the source and destination paths as arguments:
```bash
chmod +x backup.sh
./backup.sh /path/to/source /path/to/destination_dir
```
Or configure via environment variables:
```bash
BACKUP_SOURCE=/path/to/source BACKUP_DEST=/path/to/destination_dir ./backup.sh
```

### `wdw.sh` ("Who's Doing What")

A script to monitor user activity on the system. It shows who is currently logged in and provides information about their recent activity.

**Features:**
- Lists currently logged-in users and the duration of their session.
- Shows the last logged-in users.
- Displays recent file and directory commands executed by users from their `.bash_history`.

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
shellcheck adminMenu.sh backup backup.sh wdw.sh sys-cleaner/cleaner.sh sys-cleaner/tests/test_cleaner.sh

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
