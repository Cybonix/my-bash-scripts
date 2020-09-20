#!/bin/bash
# Purpose - This custom bash script backs up files in a giving folder, and could be used to automate backups.
# Modified by - Joseph Mark Orimoloye <cybonix@gmail.com>

# Files or Folders to backup.
backup_files="/home/cybonix/my-bash-scripts"

# Destination of backup.
dest="/home/cybonix"

# Create archive filename.
day=$(date "+%Y-%m-%d.%H%M")
hostname=$(hostname -s)
archive_file="$hostname-$day.tar.gz"

# Print start status message.
echo "Backing up $backup_files to $dest/$archive_file"
date
echo

# Backup the files using tar.
tar czf $dest/$archive_file $backup_files

# Print end status message.
echo "Backup Finished with status $?"
date

# Long listing of files in $dest to check file sizes.
ls -lh $dest
