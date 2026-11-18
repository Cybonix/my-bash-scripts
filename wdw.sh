#!/bin/bash
# Purpose - Monitor user activity ("Who's Doing What"): lists currently logged-in
#           users, session durations, last logged-in users, and recent file/directory
#           commands from their .bash_history.

get_real_users() {
    mapfile -t real_users < <(getent passwd | awk -F: '$3 >= 1000 && $3 <= 60000 {print $1}')
    real_users+=(root)
}

process_login() {
    local line="$1"
    local current="$2"
    local user login_time login_timestamp current_timestamp duration home_dir history_file

    [[ -z "$line" ]] && return 0

    user=$(echo "$line" | awk '{print $1}')
    login_time=$(echo "$line" | awk '{$1=$2=$3=$4=$5=""; sub(/^[ \t]+/, ""); print $0}')

    # Check if the user is a real user
    if [[ " ${real_users[*]} " == *" $user "* ]]; then
        if [[ "$current" -eq 1 ]]; then
            login_timestamp=$(date --date="$login_time" +%s)
            current_timestamp=$(date +%s)
            duration=$((current_timestamp - login_timestamp))
            echo "$user - Logged in at: $login_time - Logged in for: $((duration / 3600))h $(((duration / 60) % 60))m $((duration % 60))s"
        else
            echo "$user - Logged in at: $login_time"
        fi

        # Get the user's home directory and check if the history file exists and is readable
        home_dir=$(getent passwd "$user" | cut -d: -f6)
        history_file="$home_dir/.bash_history"
        if [[ -f "$history_file" && -r "$history_file" ]]; then
            sed -n -E 's/^(vi|nano|cat|less|more|tail|head|touch|rm|cp|mv|mkdir|rmdir|cd) /|-- &/Ip' "$history_file"
        fi
        echo
    fi
}

main() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root" >&2
        exit 1
    fi

    get_real_users

    echo "Currently logged in users:"
    while read -r line; do
        process_login "$line" 1
    done < <(who -u)

    echo "Last logged in users:"
    while read -r line; do
        process_login "$line" 0
    done < <(last -F | head -n -2)
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
