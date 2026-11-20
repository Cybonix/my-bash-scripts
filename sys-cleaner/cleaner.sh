#!/bin/bash

# System Cleaner Script
#
# A script to help identify unused files and applications on Ubuntu/Debian.
#
# Warning: This script is a powerful tool. It does not delete anything
# automatically, but helps you generate scripts to do so. Always
# review the generated scripts and back up your data before running them.

set -o pipefail

# --- Configuration ---
# Default number of days to consider a file "old"
DEFAULT_DAYS_OLD=180
# Default path to scan
DEFAULT_SCAN_PATH="$HOME"
# Excluded directories (comma-separated)
DEFAULT_EXCLUDES=".cache,.config,.local/share/Trash,.git,.vscode"

# --- UI & Helper Functions ---

# Color definitions
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_YELLOW='\033[0;33m'
C_CYAN='\033[0;36m'

info() {
    echo -e "${C_CYAN}[INFO] $1${C_RESET}"
}

warn() {
    echo -e "${C_YELLOW}[WARN] $1${C_RESET}"
}

error() {
    echo -e "${C_RED}[ERROR] $1${C_RESET}"
}

# --- File Scanning Logic ---

scan_for_old_files() {
    info "This utility will scan for files that have not been accessed recently."
    warn "Note: Access time (-atime) accuracy depends on filesystem mount options (e.g., relatime/noatime)."

    read -r -p "Enter the number of days to consider a file 'old' [Default: $DEFAULT_DAYS_OLD]: " days_old
    days_old=${days_old:-$DEFAULT_DAYS_OLD}

    if ! [[ "$days_old" =~ ^[0-9]+$ ]]; then
        error "Invalid number of days: '$days_old'. Must be a non-negative integer."
        return 1
    fi

    read -r -p "Enter the absolute path to scan [Default: $DEFAULT_SCAN_PATH]: " scan_path
    scan_path=${scan_path:-$DEFAULT_SCAN_PATH}

    read -r -p "Enter comma-separated directories to exclude [Default: $DEFAULT_EXCLUDES]: " excludes
    excludes=${excludes:-$DEFAULT_EXCLUDES}

    if [[ ! -d "$scan_path" ]]; then
        error "The path '$scan_path' does not exist or is not a directory."
        return 1
    fi

    # Normalize to an absolute path without trailing slash (preserving '/')
    scan_path=$(cd -- "$scan_path" && pwd)
    if [[ "$scan_path" != "/" ]]; then
        scan_path="${scan_path%/}"
    fi

    info "Scanning for files in '$scan_path' not accessed in the last $days_old days..."

    # Build the find command's exclude arguments
    local exclude_args=()
    local exclude_arr=()
    local item
    IFS=',' read -ra exclude_arr <<< "$excludes"
    for item in "${exclude_arr[@]}"; do
        # Trim leading/trailing whitespace and slashes
        item="${item#"${item%%[![:space:]]*}"}"
        item="${item%"${item##*[![:space:]]}"}"
        item="${item#/}"
        item="${item%/}"
        [[ -z "$item" ]] && continue
        if [[ "$item" == */* ]]; then
            # Relative subpath under scan_path (e.g., .local/share/Trash)
            exclude_args+=(-o -path "$scan_path/$item" -o -path "$scan_path/$item/*")
        else
            # Bare directory name (e.g., .git, .cache) matched at any depth
            exclude_args+=(-o -name "$item")
        fi
    done

    # The first element of exclude_args is '-o', which we don't want at the start of the expression
    if [[ ${#exclude_args[@]} -gt 0 ]]; then
        unset 'exclude_args[0]'
    else
        exclude_args=(-false)
    fi

    # Find files using NUL-delimited records so filenames with newlines/spaces/pipes are safe.
    # Format: epoch_atime|size_bytes|path\0
    local found_files=()
    mapfile -d '' -t found_files < <(find "$scan_path" \( "${exclude_args[@]}" \) -prune -o -type f -atime +"$days_old" -printf "%A@|%s|%p\0" 2>/dev/null | sort -z -n)

    if [[ ${#found_files[@]} -eq 0 ]]; then
        info "No files found matching the criteria."
        return 0
    fi

    info "Found ${#found_files[@]} old files. Displaying the top 20 largest."
    echo "----------------------------------------------------------------"
    printf "%-20s | %-12s | %s\n" "Last Accessed" "Size" "Path"
    echo "----------------------------------------------------------------"

    # Sort by size (field 2) descending and take top 20
    printf '%s\0' "${found_files[@]}" | sort -z -t'|' -k2,2nr | head -z -n 20 | while IFS='|' read -r -d '' atime size path; do
        local last_access_date human_readable_size
        last_access_date=$(date -d "@$atime" '+%Y-%m-%d %H:%M:%S')
        human_readable_size=$(numfmt --to=iec-i --suffix=B "$size")
        printf "%-20s | %-12s | %s\n" "$last_access_date" "$human_readable_size" "$path"
    done

    echo "----------------------------------------------------------------"
    warn "This is just a preview of the largest files."

    read -r -p "Do you want to generate a removal script for ALL ${#found_files[@]} found files? [y/N]: " confirm
    if [[ "$confirm" =~ ^[yY]$ ]]; then
        generate_removal_script "${found_files[@]}"
    else
        info "No action taken."
    fi
}

generate_removal_script() {
    local files_to_process=("$@")
    local script_path
    script_path="./remove_old_files_$(date +%Y%m%d_%H%M%S).sh"

    info "Generating removal script at: $script_path"

    {
        echo "#!/bin/bash"
        echo "#"
        echo "# This script was generated by the System Cleaner."
        echo "# It contains commands to delete files identified as 'old'."
        echo "#"
        echo "# !!! WARNING !!!"
        echo "# Review these commands carefully before running this script."
        echo "# Make sure you have backed up any important data."
        echo "# To execute, run: bash $script_path"
        echo ""
    } > "$script_path"

    local total_size=0
    local line size path
    # Generate safely escaped removal commands and calculate total size
    for line in "${files_to_process[@]}"; do
        IFS='|' read -r -d '' _ size path < <(printf '%s\0' "$line")
        [[ "$size" =~ ^[0-9]+$ ]] || size=0
        printf "rm -v -- %q # Size: %s\n" "$path" "$(numfmt --to=iec-i --suffix=B "$size")" >> "$script_path"
        total_size=$((total_size + size))
    done

    echo "" >> "$script_path"
    echo "# Total size of files to be removed: $(numfmt --to=iec-i --suffix=B --format="%f" "$total_size")" >> "$script_path"

    chmod +x "$script_path"
    info "Script generated successfully."
    warn "REVIEW THE SCRIPT '$script_path' AND RUN IT MANUALLY IF YOU ARE SURE."
}

# --- Application Scanning Logic ---

scan_for_applications() {
    info "This utility helps you review manually installed applications."
    echo
    echo "Choose a package manager to scan:"
    echo "1. APT (Debian packages)"
    echo "2. Snap"
    echo "3. Flatpak"
    echo "4. Back to main menu"
    echo
    read -r -p "Enter your choice [1-4]: " choice

    case "$choice" in
        1)
            scan_apt_packages
            ;;
        2)
            scan_snap_packages
            ;;
        3)
            scan_flatpak_packages
            ;;
        4)
            return
            ;;
        *)
            error "Invalid choice."
            ;;
    esac
}

scan_apt_packages() {
    info "Scanning for manually installed APT packages..."
    info "This may take a moment..."

    local packages=()
    mapfile -t packages < <(apt-mark showmanual)

    if [[ ${#packages[@]} -eq 0 ]]; then
        info "No manually installed packages found."
        return 0
    fi

    # Query all manually installed packages in a single batched dpkg-query call
    local package_details=()
    local pkg size_kb size_bytes description
    while IFS='|' read -r pkg size_kb description; do
        [[ -z "$pkg" ]] && continue
        size_kb=${size_kb:-0}
        [[ "$size_kb" =~ ^[0-9]+$ ]] || size_kb=0
        size_bytes=$((size_kb * 1024))
        package_details+=("$pkg|$size_bytes|$description")
    done < <(dpkg-query -W -f='${Package}|${Installed-Size}|${binary:summary}\n' "${packages[@]}" 2>/dev/null)

    if [[ ${#package_details[@]} -eq 0 ]]; then
        info "No manually installed packages found."
        return 0
    fi

    info "Found ${#package_details[@]} manually installed packages. Displaying them sorted by size."
    echo "--------------------------------------------------------------------------------"
    printf "%-30s | %-12s | %s\n" "Package" "Size" "Description"
    echo "--------------------------------------------------------------------------------"

    # Sort by size (field 2) descending and print
    printf '%s\n' "${package_details[@]}" | sort -t'|' -k2,2nr | while IFS='|' read -r pkg size desc; do
        local human_readable_size
        human_readable_size=$(numfmt --to=iec-i --suffix=B "$size")
        printf "%-30s | %-12s | %s\n" "$pkg" "$human_readable_size" "$desc"
    done

    echo "--------------------------------------------------------------------------------"
    warn "This list shows manually installed packages. Dependencies are not shown."

    read -r -p "Do you want to generate a removal script for selected packages? [y/N]: " confirm
    if [[ "$confirm" =~ ^[yY]$ ]]; then
        generate_app_removal_script "apt" "${package_details[@]}"
    else
        info "No action taken."
    fi
}

scan_snap_packages() {
    if ! command -v snap &> /dev/null; then
        warn "Snap command not found. Skipping snap package scan."
        return
    fi

    info "Scanning for installed Snap packages..."
    # snap list columns: Name ($1), Version ($2), Rev ($3), Tracking ($4), Publisher ($5), Notes ($6)
    local snaps=()
    mapfile -t snaps < <(snap list | tail -n +2 | awk '{print $1"|"$3"|"$5"|"$6}')

    if [[ ${#snaps[@]} -eq 0 ]]; then
        info "No Snap packages found."
        return 0
    fi

    info "Found ${#snaps[@]} Snap packages."
    echo "--------------------------------------------------------------------------------"
    printf "%-30s | %-8s | %-20s | %s\n" "Package" "Rev" "Publisher" "Notes"
    echo "--------------------------------------------------------------------------------"

    local line pkg rev publisher notes
    for line in "${snaps[@]}"; do
        IFS='|' read -r pkg rev publisher notes <<< "$line"
        printf "%-30s | %-8s | %-20s | %s\n" "$pkg" "$rev" "$publisher" "$notes"
    done
    echo "--------------------------------------------------------------------------------"

    read -r -p "Do you want to generate a removal script for selected packages? [y/N]: " confirm
    if [[ "$confirm" =~ ^[yY]$ ]]; then
        generate_app_removal_script "snap" "${snaps[@]}"
    else
        info "No action taken."
    fi
}

scan_flatpak_packages() {
    if ! command -v flatpak &> /dev/null; then
        warn "Flatpak command not found. Skipping flatpak package scan."
        return
    fi

    info "Scanning for installed Flatpak applications..."
    # Format: Application ID <TAB> Size
    local flatpaks=()
    mapfile -t flatpaks < <(flatpak list --app --columns=application,size)

    if [[ ${#flatpaks[@]} -eq 0 ]]; then
        info "No Flatpak applications found."
        return 0
    fi

    info "Found ${#flatpaks[@]} Flatpak applications."
    echo "--------------------------------------------------------------------------------"
    printf "%-50s | %s\n" "Application ID" "Size"
    echo "--------------------------------------------------------------------------------"

    local line app_id size
    local flatpak_details=()
    for line in "${flatpaks[@]}"; do
        IFS=$'\t' read -r app_id size <<< "$line"
        [[ -z "$app_id" ]] && continue
        printf "%-50s | %s\n" "$app_id" "$size"
        flatpak_details+=("$app_id|$size|")
    done
    echo "--------------------------------------------------------------------------------"

    read -r -p "Do you want to generate a removal script for selected packages? [y/N]: " confirm
    if [[ "$confirm" =~ ^[yY]$ ]]; then
        generate_app_removal_script "flatpak" "${flatpak_details[@]}"
    else
        info "No action taken."
    fi
}

generate_app_removal_script() {
    local type=$1
    shift
    local packages_to_process=("$@")
    local packages_to_remove=()

    if [[ "$USE_DIALOG" -eq 1 ]]; then
        local checklist_options=()
        local line name col2 col3
        for line in "${packages_to_process[@]}"; do
            IFS='|' read -r name col2 col3 _ <<< "$line"
            local display_name="$name"
            local display_info=""
            if [[ "$type" == "apt" ]]; then
                local human_readable_size
                human_readable_size=$(numfmt --to=iec-i --suffix=B "$col2")
                display_info="$human_readable_size - $col3"
            elif [[ "$type" == "snap" ]]; then
                display_info="Rev: $col2 - Publisher: $col3"
            elif [[ "$type" == "flatpak" && -n "$col2" ]]; then
                display_info="Size: $col2"
            fi
            checklist_options+=("$display_name" "$display_info" "off")
        done

        local selected_packages
        selected_packages=$(dialog --keep-tite --separate-output --checklist "Select packages to remove (Space to toggle)" 20 100 15 "${checklist_options[@]}" 2>&1 >/dev/tty)

        if [[ -z "$selected_packages" ]]; then
            info "No packages selected. Aborting."
            return
        fi

        mapfile -t packages_to_remove <<< "$selected_packages"

    else
        info "Please enter the exact names of the packages you want to remove."
        info "Separate multiple packages with spaces."
        read -r -p "Packages to remove: " -ra packages_to_remove
    fi

    if [[ ${#packages_to_remove[@]} -eq 0 ]]; then
        info "No packages selected. Aborting."
        return
    fi

    local script_path
    script_path="./remove_${type}_packages_$(date +%Y%m%d_%H%M%S).sh"
    info "Generating removal script at: $script_path"

    {
        echo "#!/bin/bash"
        echo "#"
        echo "# This script was generated by the System Cleaner to remove ${type} packages."
        echo "#"
        echo "# !!! WARNING !!!"
        echo "# Review these commands carefully before running this script."
        echo ""
    } > "$script_path"

    local pkg
    case "$type" in
        apt)
            printf "sudo apt-get purge --" >> "$script_path"
            for pkg in "${packages_to_remove[@]}"; do
                printf " %q" "$pkg" >> "$script_path"
            done
            echo "" >> "$script_path"
            echo "sudo apt-get autoremove" >> "$script_path"
            ;;
        snap)
            for pkg in "${packages_to_remove[@]}"; do
                printf "sudo snap remove -- %q\n" "$pkg" >> "$script_path"
            done
            ;;
        flatpak)
            printf "flatpak uninstall --delete-data --" >> "$script_path"
            for pkg in "${packages_to_remove[@]}"; do
                printf " %q" "$pkg" >> "$script_path"
            done
            echo "" >> "$script_path"
            ;;
    esac

    chmod +x "$script_path"
    info "Script generated successfully."
    warn "REVIEW THE SCRIPT '$script_path' AND RUN IT MANUALLY IF YOU ARE SURE."
}


# --- Main Logic ---

# Check for dialog and interactive TTY before enabling TUI mode
USE_DIALOG=0
if command -v dialog &> /dev/null && [[ -t 0 && -t 1 ]]; then
    USE_DIALOG=1
fi

main() {
    if [[ "$USE_DIALOG" -eq 1 ]]; then
        local cmd=(dialog --keep-tite --menu "System Cleaner" 12 50 3)
        local options=(1 "Scan for old files"
                       2 "Scan for installed applications"
                       3 "Exit")

        while true; do
            local choice
            choice=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)

            case "$choice" in
                1) scan_for_old_files ;;
                2) scan_for_applications ;;
                3) break ;;
                *) break ;; # Exit on cancel
            esac
        done
        # Clear the screen after dialog exits
        clear
    else
        # Fallback to simple text menu
        while true; do
            echo "Welcome to the System Cleaner script."
            echo "==================================="
            echo
            echo "Please choose an option:"
            echo "1. Scan for old files"
            echo "2. Scan for installed applications"
            echo "3. Exit"
            echo
            local choice
            read -r -p "Enter your choice [1-3]: " choice || break

            case "$choice" in
                1) scan_for_old_files ;;
                2) scan_for_applications ;;
                3) echo "Exiting."; exit 0 ;;
                *) error "Invalid choice. Please try again." ;;
            esac
        done
    fi
}

# --- Script Entry Point ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
