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

# function to list user accounts
one(){
	local uid_min uid_max
	uid_min=$(awk '/^UID_MIN/ {print $2}' /etc/login.defs 2>/dev/null)
	uid_max=$(awk '/^UID_MAX/ {print $2}' /etc/login.defs 2>/dev/null)
	uid_min=${uid_min:-1000}
	uid_max=${uid_max:-60000}
	getent passwd | awk -F: -v min="$uid_min" -v max="$uid_max" '$3 >= min && $3 <= max {print $1}' && sleep 2
	pause
}

# function to create admin accounts
two(){
	# Adds a user to Linux system as admin, including password
	# Am I a Root user?
	if [[ $(id -u) -eq 0 ]]; then
		local username password pass admin_group="wheel"
		read -r -p "Enter username : " username
		read -r -s -p "Enter password : " password
		echo
		if [[ -z "$username" ]]; then
			clear
			echo -e "${RED}Username cannot be empty!${STD}" && sleep 2
			pause
			return 1
		fi
		if grep -qE "^${username}:" /etc/passwd; then
			clear
			echo -e "${RED}$username already exist!${STD}" && sleep 2
			pause
		else
			pass=$(perl -e 'print crypt($ARGV[0], "password")' "$password")
			useradd -m -p "$pass" "$username"
			if ! getent group wheel >/dev/null 2>&1 && getent group sudo >/dev/null 2>&1; then
				admin_group="sudo"
			fi
			if usermod -a -G "$admin_group" "$username"; then
				clear
				echo -e "${GREEN}$username has been added to system as admin!${STD}"
			else
				clear
				echo -e "${RED}Failed to add a user!${STD}"
			fi
			pause
		fi
	else
		echo -e "${RED}Only admins may add a user to the system.${STD}" && sleep 2
		pause
	fi
}

# function to remove admin accounts
three(){
	if [[ $(id -u) -eq 0 ]]; then
		local username
		read -r -p "Enter username : " username
		if [[ -z "$username" ]] || ! grep -qE "^${username}:" /etc/passwd; then
			clear
			echo -e "${RED}$username does not exist!${STD}" && sleep 2
			pause
		else
			userdel -r "$username" && echo -e "${GREEN}$username has been deleted!${STD}" && sleep 2
			pause
		fi
	else
		echo -e "${RED}Only admins may delete a user.${STD}" && sleep 2
		pause
	fi
}

# function to display menus
show_menus() {
	clear
	echo "~~~~~~~~~~~~~~~~~~~~~~~"
	echo "  A D M I N - M E N U  "
	echo "~~~~~~~~~~~~~~~~~~~~~~~"
	echo "1. List Admin Account  "
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
