# System Cleaner Script

A bash script to help you find unused files and applications on your Ubuntu system. The goal is to help you keep your system organized and free of clutter.

## ⚠️ Important Warning

This script is designed to help you identify candidates for removal, but it **does not delete anything automatically**. Instead, it generates a separate script containing the commands to remove the items you select.

**You are responsible for:**
1.  **Backing up your data** before making any changes.
2.  **Carefully reviewing the generated removal script** before executing it.

Deleting the wrong files or applications can cause system instability or data loss. **Use this tool with caution.**

## Features

*   **File Scanning:** Find files that have not been accessed in a configurable number of days (`-atime`). Note that access-time accuracy depends on your filesystem's mount options (e.g., `relatime` or `noatime`).
*   **Application Scanning:** List manually installed APT packages (batched via `dpkg-query`), installed Snap packages (with revision, publisher, and notes), and Flatpak applications (`--app`).
*   **Safe by Design:** Does not delete anything directly. Generates a shell-escaped removal script (using `--` flag termination and NUL-safe file handling) for you to review and run.
*   **Configurable:** Customize the age threshold and excluded directories (both nested directory names like `.git` and relative subpaths like `.local/share/Trash`).

## Usage

1.  Make the script executable:
    ```bash
    chmod +x cleaner.sh
    ```
2.  Run the script:
    ```bash
    ./cleaner.sh
    ```
3.  Follow the on-screen prompts.

## Dependencies

This script may be enhanced with tools like `dialog` for a better UI. If `dialog` is not installed, you can install it with:
```bash
sudo apt-get update
sudo apt-get install dialog
```
