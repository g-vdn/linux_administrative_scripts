#!/bin/bash
# Title             : mkscript.sh
# Description       : Script which creates .sh files with the header already populated
# Author            : g-vdn
# E-Mail            : contact@gvdn.cz
# Creation Date     : 27-March-2022
# Latest Update     : N/A
# Version           : 0.1
# Usage             : ./mkscript.sh
# Notes             : N/A 
# Bash Version      : 5.0.3(1)-release
# ====================================================================================================

####################
# Global Variables #
####################

TODAY="$(date +%d-%B-%Y)"
SEPARATOR="$(for i in $(seq 50);do printf "=";done)"
EDITORS=("Vim" "Nano" "Quit") # if this array is changed, change the select_text_editor function also
CURSOR_LINE='+14' # line on which to place the cursor when opening with a text editor

# Check if tput command is available
if type tput &> /dev/null; then
    TPUT=true
else
    TPUT=false
fi

#############
# Functions #
#############

show_usage() {

# Help user on script usage
printf "\
%-s\n\n\
%-s\n\
\t%-10s %-s\n\
\t%-10s %-s\n\
\t%-10s %-s\n\
\t%-10s %-s\n\
\t%-10s %-s\n\
\t%-10s %-s\n\
\t%-10s %-s\n\
" \
"Usage: $(basename ${0}) -g || -n name [-advo] [arg ...]" \
"Options:" \
"-g" "Guided mode" \
"-n" "Script name" \
"-a" "Author name" \
"-m" "E-Mail address" \
"-d" "Script description" \
"-v" "Script version" \
"-o" "Open with a text editor: '-o vim' or '-o nano'"
}

create_file_and_header() {

# Format the output and write it to a file.
printf "\
%-s\n\
%-20s%-5s%-s\n\
%-20s%-5s%-s\n\
%-20s%-5s%-s\n\
%-20s%-5s%-s\n\
%-20s%-5s%-s\n\
%-20s%-5s%-s\n\
%-20s%-5s%-s\n\
%-20s%-5s%-s\n\
%-20s%-5s%-s\n\
%-20s%-5s%-s\n\
%-s\
\n\n\n\
" \
'#!/bin/bash' \
'# Title' ':' "${NAME}" \
'# Description' ':' "${DESCR}" \
'# Author' ':' "${AUTHOR}" \
'# E-Mail' ':' "${E_MAIL}" \
'# Creation Date' ':' "${TODAY}" \
'# Latest Update' ':' 'N/A' \
'# Version' ':' "${VER}" \
'# Usage' ':' "./${NAME}" \
'# Notes' ':' 'N/A' \
'# Bash Version' ':' "${BASH_VERSION}" \
"# ${SEPARATOR}${SEPARATOR}" \
> "${NAME}"

chmod +x "${NAME}" # make file executable
}

open_error() {
# print error message in case invalid option is specified
printf "\
%-s\n\
%-s\n\n\
" \
"File '${NAME}' created, but it cannot be automatically open --> Invalid selection for text editor: '${OPEN}'" \
"Valid options are: '$(for i in ${!EDITORS[@]}; do printf "%s " ${EDITORS[$i],,};done)'" >&2
}

format_name_var() {

    # Replace the spaces from the title with underlines.
    NAME="${NAME// /_}"

    # Convert uppercase to lowercase.
    NAME="${NAME,,}"

    # Add .sh to the end of the title if it is not there already.
    [[ "${NAME:(-3)}" != '.sh' ]] && NAME="${NAME}.sh"
}

var_reassign() {
    # If user skips naming, set to n/a
    if ! (( ${#VER} )) ; then VER='N/A';fi
    if ! (( ${#DESCR} )); then DESCR='N/A';fi
    if ! (( ${#AUTHOR} )); then AUTHOR='N/A';fi
    if ! (( ${#E_MAIL} )); then
        E_MAIL='N/A'
    else
        if ! echo ${E_MAIL} | grep -q -P "(^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$)"; then
            echo -e "\nInfo: Invalid E-Mail format: '${E_MAIL}'. Modify if necessary in the created script file."
            read -p "Press enter to acknowledge and continue..."
        fi
    fi

}

select_script_details(){

    # Get the user input.
    read -r -p "Enter a name for the script (Mandatory) : " NAME

    # Check if name is specified
    if ! (( ${#NAME} )); then
        clear
        printf "%s\n\n" "Script name cannot be empty. Try again."
        select_script_details
        return
    else
        format_name_var
    fi

    # Check to see if the file exists already.
    if [[ -e "${NAME}" ]] ; then
        clear
        printf "%s\n%s\n\n" "The script \"${NAME}\" already exists in $(realpath .)" \
        "Please select another script name."
        select_script_details
        return
    fi

}

select_text_editor(){

# Select between Vim or Nano.
PS3='Select an editor to open the script with: '
select EDITOR in "${EDITORS[@]}"; do
    # Open the file with the cursor on the 14th line.
    case "${EDITOR}" in
         "Vim") vim "${CURSOR_LINE}" "${NAME}"
                ${TPUT} && tput rmcup
                ${TPUT} || clear
                exit 0
                ;;
        "Nano") nano "${CURSOR_LINE}" "${NAME}"
                ${TPUT} && tput rmcup
                ${TPUT} || clear
                exit 0
                ;;
        "Quit")
                clear
                echo "File '${NAME}' created. Script will now exit."
                read -p "Press enter to acknowledge and continue..."
                ${TPUT} && tput rmcup
                ${TPUT} || clear
                exit 0
                ;;
             *)
                clear
                printf "%s%s\n" "Invalid option selected for text editor. " "Try again."
                select_text_editor
                return
                ;;
    esac
done
}

#######################
# Beginning of script #
#######################

while getopts gv:d:n:a:o:m: OPTION; do
    case ${OPTION} in
        g) GUIDED='true' ;;
        v) VER="${OPTARG}";;
        d) DESCR="${OPTARG}" ;;
        n) NAME="${OPTARG}" ;;
        a) AUTHOR="${OPTARG}" ;;
        o) OPEN="${OPTARG}" ;;
        m) E_MAIL="${OPTARG}" ;;
        ?) show_usage; exit ;;
    esac
done

# If no arguments are provided, show usage
if [[ "${#}" -lt 1 ]]; then
    show_usage
    exit 0
fi

# If GUIDED is set to true, run guided mode
if [[ ${GUIDED} = 'true' ]]; then # guided

    # Clear the clutter
    ${TPUT} && tput smcup && tput home # If tput exists, use it to save and restore screen contents
    ${TPUT} || clear # If tput doesn't exist, use clear insteadb

    select_script_details # Get necessary details from the user

    read -r -p "Enter your name (Optional, ENTER to skip) : " AUTHOR
    read -r -p "Enter a description (Optional, ENTER to skip) : " DESCR
    read -r -p "Enter the version number (Optional, ENTER to skip) : " VER
    read -r -p "Provide e-mail address? (Optional, ENTER to skip) : " E_MAIL

    var_reassign # if user skips naming variables, set to n/a

    create_file_and_header # Using the provided info, create the file and write the header

    clear # clear screen between getting script details and text editor

    select_text_editor # Prompt user to select desired tex editor
fi

# If NAME unset, exit
if ! (( ${NAME+1} )); then
    printf "Error: Script name is mandatory. Try again.\n\n" >&2
    show_usage
    exit 1
else
    # format variable for script name
    format_name_var

    # Check if file with name already exists
    if [[ -e "${NAME}" ]] ; then
        echo "Error: Script name '${NAME}' already exists in '$(realpath .)'. Pick another one. " >&2
        exit 1
    fi

    var_reassign # if user skips naming variables, set to n/a

    create_file_and_header # Using the provided info, create the file and write the header


    # check if OPEN is created and if so, its contents
    if (( ${OPEN+1} )); then
        COM="${OPEN} ${CURSOR_LINE} ${NAME}"
        case ${OPEN} in
             vim) ${COM} ;;
            nano) ${COM} ;;
               *) open_error ;;
        esac
    fi
fi
