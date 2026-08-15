#!/bin/bash
# Purpose - This custom bash script backs up files in a giving folder, and could be used to automate backups.
# Modified by - Joseph Mark Orimoloye <cybonix@gmail.com>

# Default to environment variables or arguments, fallback to reasonable defaults
backup_files="${1:-${BACKUP_SOURCE:-}}"
dest="${2:-${BACKUP_DEST:-}}"

if [[ -z "$backup_files" || -z "$dest" ]]; then
	echo "Usage: $0 <source_file_or_directory> <destination_directory>" >&2
	echo "Or set BACKUP_SOURCE and BACKUP_DEST environment variables." >&2
	exit 1
fi

if [[ ! -e "$backup_files" ]]; then
	echo "Error: Source '$backup_files' does not exist." >&2
	exit 1
fi

if [[ ! -d "$dest" ]]; then
	echo "Error: Destination directory '$dest' does not exist." >&2
	exit 1
fi

# Create archive filename.
day=$(date "+%Y-%m-%d.%H%M")
hostname=$(hostname -s)
archive_file="$hostname-$day.tar.gz"

# Print start status message.
echo "Backing up $backup_files to $dest/$archive_file"
date
echo

# Backup the files using tar.
if tar czf "$dest/$archive_file" "$backup_files"; then
	# Print end status message.
	echo "Backup Finished with status 0"
	date

	# Long listing of files in $dest to check file sizes.
	ls -lh "$dest/$archive_file"
else
	echo "Backup failed!" >&2
	exit 1
fi
