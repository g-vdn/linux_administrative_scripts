#!/bin/bash         
# Title             : cronjobs.sh   
# Description       : Displays the cronjobs for all the users on the system
# Author            : gvdn       
# E-Mail            : contact@gvdn.cz       
# Creation Date     : 18-August-2021
# Latest Update     : 27-March-2022       
# Version           : 1.1       
# Usage             : sudo ./cronjobs.sh
# Notes             : Script with administrative purpose
# Bash Version      : 5.0.3(1)-release
# ====================================================================================================

####################################################
# Change below 3 variables according to your needs #
####################################################

# Use '-i' option to install as alias in user .bashrc: ./cronjobs -i

BASHRC="${HOME}/.bashrc" # Change if .bashrc file is located elsewhere
ALIAS_NAME='cronjobs' # Name with which you want to run the script
TODAY="$(date +%d-%B-%Y)" # Change date format if required, use `man date` to see other date possibilities
FIRST='1' # will display a message first time the script is run. To reset, change value 0



##############################################################
# Do not modify anything under this line or script may break #
##############################################################


# Inform about posibility to install as an alias
if [[ ${FIRST} = '0' ]]; then
    printf "%-s\n" "NOTE: This script will show the set-up cron jobs for all users on this system, regardless of their nature. Sudo privileges requiered. For ease of use, you can run the script with '-i' option to install as alias: '${0} -i' . If required, you can modify the variables inside the script file. This message will show only one time."
    read -p "Press enter to acknowledge and continue..."
    sed -i "0,/FIRST='0'/ s//FIRST='1'/" $(basename ${0})
    exit 0
fi



# Checks


# Install as alias if -i option is used, append lines in bashrc user file
if [[ ${1} = '-i' ]]; then
    if [[ -w ${BASHRC} ]]; then
        printf "%-s\n%-s\n" "########## Custom Aliases ${TODAY} ##########" "alias ${ALIAS_NAME}='/opt/scripts/cronjobs.sh'" >> ${BASHRC} && source ${BASHRC}
        printf "%-s\n" "Successfully installed as alias. Now you can run cronjobs command from everywhere."
        exit 0
    else
        printf "%-s\n%-s" "File located at '${BASHRC}' non-existent or not writable by you." \
        "Check BASHRC variable in script $(realpath ${0})"
    fi
else
    if (( ${1+1} )); then
        printf "%-s\n" "Invalid option. Only -i is accepted which will install " >&2
        exit 1
    fi
fi

# Make sure sudo 
if [[ ${UID} -ne 0 ]]; then
    echo "Script must be run as root or with sudo privileges" >&2
    exit 1
fi



# Actual script


SEPARATOR="$(for i in $(seq $(tput cols));do echo -n "-";done)"

cut -d ":" -f 1 /etc/passwd | \
while read USER; do
	if [[ "$(sudo -u $USER crontab -l 2>&1 > /dev/null)" != no* ]]; then
		echo $SEPARATOR
		printf "\e[34mCrontabs for user: \e[0m$USER\n"
		sudo -u $USER crontab -l | sed 's/^\s*#.*//g;s/^\s*MAILTO.*//g;/^$/d'
		echo $SEPARATOR && echo
	fi
done
