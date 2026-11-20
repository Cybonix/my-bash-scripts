#!/bin/bash
# Purpose - Monitor user activity ("Who's Doing What"): lists currently logged-in
#           users, session durations, last logged-in users, and recent file/directory
#           commands from their .bash_history.

declare -a real_users=()
declare -A seen_history=()

get_real_users() {
    local uid_min uid_max
    uid_min=$(awk '/^UID_MIN/ {print $2}' /etc/login.defs 2>/dev/null)
    uid_max=$(awk '/^UID_MAX/ {print $2}' /etc/login.defs 2>/dev/null)
    uid_min=${uid_min:-1000}
    uid_max=${uid_max:-60000}

    mapfile -t real_users < <(getent passwd | awk -F: -v min="$uid_min" -v max="$uid_max" '$3 >= min && $3 <= max {print $1}')
    real_users+=(root)
}

process_login() {
    local line="$1"
    local current="$2"
    local user login_time login_timestamp current_timestamp duration home_dir history_file
    local f3 f4 f5
    local ts_regex='(Mon|Tue|Wed|Thu|Fri|Sat|Sun) (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[[:space:]]+[0-9]{1,2}[[:space:]]+[0-9]{2}:[0-9]{2}:[0-9]{2}[[:space:]]+[0-9]{4}.*'

    [[ -z "$line" || "$line" == "wtmp begins"* ]] && return 0

    read -r user _ f3 f4 f5 _ <<< "$line"

    if [[ "$current" -eq 1 ]]; then
        if [[ "$f3" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
            login_time="$f3 $f4"
        else
            login_time="$f3 $f4 $f5"
        fi
    else
        if [[ "$line" =~ $ts_regex ]]; then
            login_time="${BASH_REMATCH[0]}"
        else
            read -r _ _ login_time <<< "$line"
        fi
    fi

    # Check if the user is a real user
    if [[ " ${real_users[*]} " == *" $user "* ]]; then
        if [[ "$current" -eq 1 ]]; then
            login_timestamp=$(date --date="$login_time" +%s 2>/dev/null)
            current_timestamp=$(date +%s)
            if [[ "$login_timestamp" =~ ^[0-9]+$ && "$current_timestamp" =~ ^[0-9]+$ ]]; then
                duration=$((current_timestamp - login_timestamp))
                if [[ "$duration" -lt 0 ]]; then
                    duration=0
                fi
                echo "$user - Logged in at: $login_time - Logged in for: $((duration / 3600))h $(((duration / 60) % 60))m $((duration % 60))s"
            else
                echo "$user - Logged in at: $login_time - Logged in for: unknown"
            fi
        else
            echo "$user - Logged in at: $login_time"
        fi

        # Print matching .bash_history commands once per user to avoid repetitive dumps
        if [[ -z "${seen_history[$user]+x}" ]]; then
            seen_history["$user"]=1
            home_dir=$(getent passwd "$user" | cut -d: -f6)
            history_file="$home_dir/.bash_history"
            if [[ -f "$history_file" && -r "$history_file" ]]; then
                sed -n -E 's/^(vi|vim|nano|cat|less|more|tail|head|touch|rm|cp|mv|mkdir|rmdir|cd)[[:space:]]+/|-- &/Ip' "$history_file"
            fi
        fi
        echo
    fi
}

main() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root" >&2
        exit 1
    fi

    seen_history=()
    get_real_users

    echo "Currently logged in users:"
    while IFS= read -r line; do
        process_login "$line" 1
    done < <(LC_ALL=C who -u)

    echo "Last logged in users:"
    while IFS= read -r line; do
        process_login "$line" 0
    done < <(LC_ALL=C last -F)
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
