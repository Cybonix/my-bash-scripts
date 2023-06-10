#!/bin/bash

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Get the list of last logged-in users
logins=$(last -F | head -n -2)

# Traverse through each login
while IFS= read -r line; do
    # Extract the username and login time
    user=$(echo "$line" | awk '{print $1}')
    login_time=$(echo "$line" | awk '{$1=$2=$3=""; print $0}')

    # Print the user and login time
    echo "$user - Logged in at: $login_time"
    
    # Check if the history file exists and is readable
    history_file="/home/$user/.bash_history"
    if [ ! -f "$history_file" ]; then
        echo "|-- No accessible history file"
        continue
    fi

    # Get commands that likely involve a file
    file_commands=$(egrep -i '^(vi|nano|cat|less|more|tail|head|touch|rm|cp|mv|mkdir|rmdir|cd) ' "$history_file")

    # Print each command in a tree-like structure
    while IFS= read -r command; do
        echo "|-- $command"
    done <<< "$file_commands"

    # Add extra line for clarity
    echo
done <<< "$logins"
