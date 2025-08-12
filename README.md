# Linux System Administration Scripts

This repository contains a collection of bash scripts for Linux system administration. These scripts are designed to simplify common tasks such as user management, backups, system monitoring, and cleanup.

## Scripts

Here is a list of the scripts available in this repository:

### `adminMenu.sh`

A menu-driven shell script for managing administrative accounts on a Linux system.

**Features:**
- List all admin accounts.
- Add a new admin user with a password.
- Remove an existing admin user.

**Usage:**
```bash
chmod +x adminMenu.sh
sudo ./adminMenu.sh
```

### `backup.sh`

A simple script to create a compressed backup of a specified directory.

**Features:**
- Backs up a folder to a `.tar.gz` archive.
- The archive is named with the hostname and a timestamp.

**Usage:**
1.  Open the script and modify the `backup_files` and `dest` variables to match your needs.
2.  Run the script:
    ```bash
    chmod +x backup.sh
    ./backup.sh
    ```

### `wdw.sh` ("Who's Doing What")

A script to monitor user activity on the system. It shows who is currently logged in and provides information about their recent activity.

**Features:**
- Lists currently logged-in users and the duration of their session.
- Shows the last logged-in users.
- Displays recent commands executed by users from their `.bash_history`.

**Usage:**
```bash
chmod +x wdw.sh
sudo ./wdw.sh
```

### `sys-cleaner/`

A utility to help you find and remove unused files and applications from your Ubuntu system.

**Features:**
- **Find Old Files:** Scans for files that haven't been accessed in a configurable number of days.
- **Scan Applications:** Lists manually installed packages from APT, Snap, and Flatpak.
- **Safe by Design:** It does not delete anything automatically. Instead, it generates a removal script for you to review and execute.
- **Interactive UI:** Uses `dialog` for a user-friendly menu if it's installed.

**Usage:**
Navigate to the `sys-cleaner` directory and run the script.
```bash
cd sys-cleaner
chmod +x cleaner.sh
./cleaner.sh
```
For more details, please refer to the `sys-cleaner/README.md` file.

## General Usage

To run any of these scripts, you first need to make them executable:
```bash
chmod +x <script_name>.sh
```
Some scripts may require root privileges to run. Use `sudo` to execute them.

## Contributions

Contributions are welcome! If you have a script that you think would be a good addition to this collection, feel free to open a pull request.
