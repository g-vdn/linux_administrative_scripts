#!/bin/bash         
# Title             : cronjobs.sh   
# Description       : Displays the cronjobs for all the users on the system
# Author            : gvdn       
# E-Mail            : contact@gvdn.cz       
# Creation Date     : 18-August-2021
# Latest Update     : 03-April-2022
# Version           : 1.1       
# Usage             : sudo ./cronjobs.sh
# Notes             : Script with administrative purpose
# Bash Version      : 5.0.3(1)-release
# ====================================================================================================

###############################################################
# If required, change below variables according to your needs #
###############################################################

BASHRC="${HOME}/.bashrc" # Change if .bashrc file is located elsewhere

ALIAS_NAME='cronjobs' # Name with which you want to run the script, after it is installed as alias

TODAY="$(date +%d-%b-%Y)" # Date will be insterted in the header before the alias is written to bashrc file.
                          # Change date format if required, use `man date` to see other date possibilities

FIRST='0' # will display a message first time the script is run. To reset, change value to 0

##############################################################
# Do not modify anything under this line or script may break #
##############################################################

###########################
# Variables and functions #
###########################

REQ=("realpath" "basename" "printf" "whoami" "tput") # required installed commands
INSTALL=false # set INSTALL by default to false

sep() {
    # custom separator, screen width
    for i in $(seq $(tput cols));do printf "${1}";done
}

usage() {
    # shows the usage
sep '+'
printf "\
%-s\n\n\
%-s\n\
%-s\n\
%-s\t%-s\n\
%-s\t%-s\n\
" \
"Usage: $(basename ${0}) [-iv]" \
"Run without any options will print all installed crontabs - user must be in sudoers or script to be run with sudo" \
"Options:" \
"[-i]" "Install as alias for user - user must be in sudoers file." \
"[-h]" "Print this help."
sep '+'
}

# If some required commands not found on system, store them in MIS
for i in ${!REQ[@]}; do
    if ! type ${REQ[$i]} &> /dev/null; then
        MIS+=("${REQ[$i]}")
    fi
done

# If MIS created, means that some required commands not installed. Inform user and exit
if (( ${MIS+1} )); then
    echo "Error: One or more required commands not found on system: '${MIS[@]}'" >&2
    echo "Install them and retry the script." >&2
    exit 1
fi

# Check if user can run commands with sudo 
if ! $(sudo -nl &> /dev/null || sudo -nv &> /dev/null); then
    echo "Error: User '$(whoami)' cannot run commands with sudo, stopping script." >&2
    exit 1
fi

# Show one time message
if [[ ${FIRST} = '0' ]]; then
sep '/'
printf "\
%-s\n\
%-s\n\
%-s\n\
%-s\n\
%-s\n\
%-s\n\
%-s\n\
" \
"NOTE:" \
"- Usage: $(basename ${0}) -h" \
"- This script will print on screen installed crontabs for all users on this system, regardless of their nature." \
"- For the script to run successfully, user must be in sudoers file or to be able to execute commands with sudo." \
"- For ease of use, you can run the script with '-i' option to install as alias: '${0} -i'" \
"- If required, you can modify the variables inside the script file." \
"- This message will not be shown on future runs. To show it again, modify FIRST variable in script to '0'."
sep '/'
    read -p "Press ENTER to acknowledge and continue or CTRL + C to cancel"
    sed -i "0,/FIRST='0'/ s//FIRST='1'/" $(basename ${0})
    exit 0
fi

# Get the user option
while getopts ih OPTION; do
    case ${OPTION} in
        i) INSTALL=true ;;
        h) usage 
           exit 0
           ;;
        *) usage 
           exit 1
           ;;
    esac
done

# Append lines in bashrc file if -i option was used 
if [[ "${INSTALL}" = 'true' ]]; then
    if [[ -w ${BASHRC} ]]; then
        if ! grep -q "Custom Aliases" "${BASHRC}" && ! grep -q "${ALIAS_NAME}" "${BASHRC}"; then     
            printf "\n%-s\n\n" "Following lines were added to user bashrc file:" 
            printf "%-s\n%-s\n%-s\n\n" \
            "########## Custom Aliases ${TODAY} ##########" \
            "alias ${ALIAS_NAME}='$(realpath ${0})'" \
            "#########################################" | tee -a ${BASHRC}
            printf "%-s\n" "Important: Due to shell limitations, there is needed to manually execute command: 'source ${BASHRC}' or restart shell."
            exit 0
        else
            echo "Error: bashrc file already contains alias entries related to this script. Please manually check the file at ${BASHRC}" >&2
            exit 1
        fi
    else
        printf "%-s\n%-s\n" "Error: File located at '${BASHRC}' non-existent or not writable by you." \
        "Check BASHRC variable in script $(realpath ${0})" >&2
        exit 1
    fi
fi

# Actual script
HT='Installed crontabs on this system' # Header Title
MID="$(( $(( $( tput cols) / 2 )) - $(( ${#HT} / 2 )) ))" # get the start column for the header message
sep '='
printf "%-${MID}s%-s\n" "" "${HT}" 
sep '='
echo
cut -d ":" -f 1 /etc/passwd | \
while read USER; do
	if sudo -u $USER crontab -l &> /dev/null; then
        sep '-'
		printf "\e[34mCrontabs for user: \e[0m$USER\n"
		sudo -u $USER crontab -l | sed 's/^\s*#.*//g;s/^\s*MAILTO.*//g;/^$/d'
        sep '-'
        echo
	fi
done
