#!/bin/bash
# Purpose - A menu driven shell script to add or remove admin accounts.
# Modified by - Joseph Mark Orimoloye <joseph.m.orimoloye.civ@mail.mil>
# ----------------------------------
# Step #1: Define variables
# ----------------------------------
RED='\033[0;41;30m'
GREEN='\033[0;42;30m'
STD='\033[0;0;39m'

# ----------------------------------
# Step #2: User defined functions
# ----------------------------------
pause(){
  read -r -p "Press [Enter] key to continue..." _
}

is_valid_username(){
	[[ "$1" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]
}

# function to list admin accounts (members of wheel / sudo groups)
one(){
	local group members found=0
	local -A seen=()
	for group in wheel sudo; do
		members=$(getent group "$group" 2>/dev/null | cut -d: -f4)
		if [[ -n "$members" ]]; then
			IFS=',' read -ra user_list <<< "$members"
			for user in "${user_list[@]}"; do
				if [[ -n "$user" && -z "${seen[$user]+x}" ]]; then
					seen["$user"]=1
					echo "$user ($group)"
					found=1
				fi
			done
		fi
	done
	if [[ "$found" -eq 0 ]]; then
		echo "No admin accounts found in wheel or sudo groups."
	fi
	sleep 2
	pause
}

# function to create admin accounts
two(){
	# Adds a user to Linux system as admin, including password
	# Am I a Root user?
	if [[ $(id -u) -eq 0 ]]; then
		local username password admin_group=""
		read -r -p "Enter username : " username
		read -r -s -p "Enter password : " password
		echo
		if [[ -z "$username" ]]; then
			clear
			echo -e "${RED}Username cannot be empty!${STD}" && sleep 2
			pause
			return 1
		fi
		if ! is_valid_username "$username"; then
			clear
			echo -e "${RED}Invalid username '$username'! Use lowercase letters, digits, '_' or '-'.${STD}" && sleep 2
			pause
			return 1
		fi
		if [[ -z "$password" ]]; then
			clear
			echo -e "${RED}Password cannot be empty!${STD}" && sleep 2
			pause
			return 1
		fi
		if getent passwd "$username" >/dev/null 2>&1; then
			clear
			echo -e "${RED}$username already exists!${STD}" && sleep 2
			pause
			return 1
		fi

		if getent group wheel >/dev/null 2>&1; then
			admin_group="wheel"
		elif getent group sudo >/dev/null 2>&1; then
			admin_group="sudo"
		else
			clear
			echo -e "${RED}No admin group (wheel or sudo) found!${STD}" && sleep 2
			pause
			return 1
		fi

		if ! useradd -m -G "$admin_group" "$username"; then
			clear
			echo -e "${RED}Failed to add user '$username'!${STD}" && sleep 2
			pause
			return 1
		fi

		if printf '%s:%s\n' "$username" "$password" | chpasswd; then
			clear
			echo -e "${GREEN}$username has been added to system as admin ($admin_group)!${STD}"
		else
			userdel -r "$username" >/dev/null 2>&1 || true
			clear
			echo -e "${RED}Failed to set password for '$username'; user creation rolled back.${STD}"
			pause
			return 1
		fi
		pause
	else
		echo -e "${RED}Only admins may add a user to the system.${STD}" && sleep 2
		pause
		return 1
	fi
}

# function to remove admin accounts
three(){
	if [[ $(id -u) -eq 0 ]]; then
		local username confirm
		read -r -p "Enter username : " username
		if [[ -z "$username" ]] || ! is_valid_username "$username"; then
			clear
			echo -e "${RED}Invalid username '$username'!${STD}" && sleep 2
			pause
			return 1
		fi
		if [[ "$username" == "root" ]]; then
			clear
			echo -e "${RED}Refusing to delete the root account!${STD}" && sleep 2
			pause
			return 1
		fi
		if ! getent passwd "$username" >/dev/null 2>&1; then
			clear
			echo -e "${RED}$username does not exist!${STD}" && sleep 2
			pause
			return 1
		fi

		read -r -p "Are you sure you want to delete '$username' and their home directory? [y/N]: " confirm
		if [[ ! "$confirm" =~ ^[yY]$ ]]; then
			echo "Deletion cancelled." && sleep 2
			pause
			return 0
		fi

		if userdel -r "$username"; then
			echo -e "${GREEN}$username has been deleted!${STD}" && sleep 2
		else
			echo -e "${RED}Failed to delete '$username'!${STD}" && sleep 2
			pause
			return 1
		fi
		pause
	else
		echo -e "${RED}Only admins may delete a user.${STD}" && sleep 2
		pause
		return 1
	fi
}

# function to display menus
show_menus() {
	clear
	echo "~~~~~~~~~~~~~~~~~~~~~~~"
	echo "  A D M I N - M E N U  "
	echo "~~~~~~~~~~~~~~~~~~~~~~~"
	echo "1. List Admin Accounts "
	echo "2. Create Admin Account"
	echo "3. Delete Admin Account"
	echo "4. Exit                "
}

# read input from the keyboard and take a action
# invoke the one() when the user select 1 from the menu option.
# invoke the two() when the user select 2 from the menu option.
# invoke the three() when the user select 3 from the menu option.
# Exit when user select 4 from the menu option.
read_options(){
	local choice
	read -r -p "Enter choice [ 1 - 4] " choice
	case $choice in
		1) one ;;
		2) two ;;
		3) three ;;
		4) clear; exit 0;;
		*) echo -e "${RED}Error...${STD}" && sleep 2
	esac
}

main() {
	# ----------------------------------------------
	# Step #3: Trap CTRL+C, CTRL+Z and quit singles
	# ----------------------------------------------
	trap '' SIGINT SIGQUIT SIGTSTP

	# -----------------------------------
	# Step #4: Main logic - infinite loop
	# ------------------------------------
	while true
	do
		show_menus
		read_options
	done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	main "$@"
fi
