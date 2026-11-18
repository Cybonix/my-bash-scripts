#!/bin/bash
# Purpose - A unified backup script/function that supports both in-place file backups
#           (<file>.YYYY-MM-DD.HHMM.bak) and compressed tarball backups (<hostname>-YYYY-MM-DD.HHMM.tar.gz)
#           when a destination directory is specified.
# Modified by - Joseph Mark Orimoloye <cybonix@gmail.com>

backup() {
	local backup_files="${1:-${BACKUP_SOURCE:-}}"
	local dest="${2:-${BACKUP_DEST:-}}"

	if [[ -z "$backup_files" ]]; then
		echo "Usage: ${FUNCNAME[0]} <source_file_or_directory> [destination_directory]" >&2
		echo "  - If destination_directory is omitted and source is a file, creates an in-place .bak copy." >&2
		echo "  - If destination_directory is provided, creates a compressed .tar.gz archive in destination_directory." >&2
		echo "  - Or set BACKUP_SOURCE (and optionally BACKUP_DEST) environment variables." >&2
		return 1
	fi

	if [[ ! -e "$backup_files" ]]; then
		echo "Error: Source '$backup_files' does not exist." >&2
		return 1
	fi

	# Mode 1: In-place file backup when no destination directory is provided
	if [[ -z "$dest" ]]; then
		if [[ -d "$backup_files" ]]; then
			echo "Error: Source '$backup_files' is a directory. Please specify a destination directory for tarball backup." >&2
			return 1
		fi
		local date_stamp
		date_stamp=$(date "+%Y-%m-%d.%H%M.bak")
		# Avoid double .bak if date_stamp already ends with .bak (e.g. from custom date format/mock)
		if [[ "$date_stamp" != *.bak ]]; then
			date_stamp="${date_stamp}.bak"
		fi
		local newname="${backup_files}.${date_stamp}"
		if cp -p "$backup_files" "$newname"; then
			echo "Backed up $backup_files to $newname."
			return 0
		else
			echo "Error: Failed to back up '$backup_files'." >&2
			return 1
		fi
	fi

	# Mode 2: Compressed tarball archive in destination directory
	if [[ ! -d "$dest" ]]; then
		echo "Error: Destination directory '$dest' does not exist." >&2
		return 1
	fi

	local day hostname archive_file
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
		return 1
	fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	backup "$@"
fi
