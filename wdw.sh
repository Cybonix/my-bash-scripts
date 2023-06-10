#!/bin/bash

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Get the list of real users
real_users=$(awk -F: '$3 >= 1000 && $3 <= 60000 {print $1}' /etc/passwd)

# Add root user to the list
real_users=$(echo -e "$real_users\nroot")

# Get the list of current logged-in users
current_logins=$(who -u)

# Function to process each user login
process_login() {
    local line="$1"
    local current="$2"

    # Extract the username and login time
    user=$(echo "$line" | awk '{print $1}')
    login_time=$(echo "$line" | awk '{$1=$2=$3=$4=$5=""; print $0}')

    # Check if the user is a real user or root
    if echo "$real_users" | grep -q "^$user$"; then
        # Print the user and login time
        if [ "$current" -eq 1 ]; then
            # For currently logged in users, calculate how long they've been logged in
            login_timestamp=$(date --date="$login_time" +%s)
            current_timestamp=$(date +%s)
            duration=$((current_timestamp - login_timestamp))
            echo "$user - Logged in at: $login_time - Logged in for: $((duration / 3600))h $(((duration / 60) % 60))m $((duration % 60))s"
        else
            echo "$user - Logged in at: $login_time"
        fi

        # Check if the history file exists and is readable
        history_file="/home/$user/.bash_history"
        if [ -f "$history_file" ]; then
            # Get commands that likely involve a file
            file_commands=$(egrep -i '^(vi|nano|cat|less|more|tail|head|touch|rm|cp|mv|mkdir|rmdir|cd) ' "$history_file")

            # Print each command in a tree-like structure
            while IFS= read -r command; do
                echo "|-- $command"
            done <<< "$file_commands"
        fi

        # Add extra line for clarity
        echo
    fi
}

# Print information about currently logged in users
echo "Currently logged in users:"
while IFS= read -r line; do
    process_login "$line" 1
done <<< "$current_logins"

# Get the list of last logged-in instances
last_logins=$(last -F | head -n -2)

# Print information about last logged in users
echo "Last logged in users:"
while IFS= read -r line; do
    process_login "$line" 0
done <<< "$last_logins"
