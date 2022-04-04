#!/bin/bash         
# Title             : cloudflare_ddns_update.sh
# Description       : Dynamic DNS IP updater
# Author            : gvdn      
# E-Mail            : contact@gvdn.cz
# Creation Date     : 30-March-2022
# Latest Update     : 04-April-2022       
# Version           : 0.2       
# Usage             : ./cloudflare_ddns_update.sh
# Notes             : N/A       
# Bash Version      : 5.0.3(1)-release
# ====================================================================================================

########################################
# User variables - need to be modified #
########################################

API='' # Cloudflare API key. Ex.: 'jg2-AlOvr3EMuokCxv0A7SOclda4yhk1pMLP_gFf'

E_MAIL='' # E-Mail used to login on Cloudflare account. Ex.: john.doe@example.com

ZONE='' # Domain for which to update the DNS record. Ex.: example.com

SUBZONE='' # Sub-domain for which the IP update should take place. Leave empty if no sub-domain present. 
           # Write only the sub-domain name, not the full domain. 
           # Ex.: if you have test.example.com you will write only test

PROXIED='' # true or false - if it is requested to proxify the sub-domain through cloudflare 

TYPE='' # A (IPv4) or AAAA (IPv6) - the DNS Record type with which you want to update the domain or sub-domain

TTL='' # Time to live, in seconds, of the DNS record. Must be between 60 and 86400, or 1 for 'automatic'

##########################################################################
# !!!!! Do not change anything under this line or script may break !!!!! #
##########################################################################

###########################
# Variables and functions #
###########################

# Main variables to build the curl commands
GET='curl -s -X GET'
PUT='curl -s -X PUT'
ENDPOINT='https://api.cloudflare.com/client/v4/'
HEADERS="-H \"X-Auth-Email: ${E_MAIL}\" -H \"Authorization: Bearer ${API}\" -H \"Content-Type: application/json\""
AUTH="-H \"Authorization: Bearer ${API}\""

# Default to false unless otherwise stated by the user via options
VERBOSE=false 
CREATE_LOG=false
FORCED=false

# Log filename
LOG_NAME="cddns_$(date '+%d%m%y_%H%M%S').log"

# Build sub-domain
if [[ -z "${SUBZONE}" ]]; then
    RECORD="${ZONE}"
else
    RECORD="${SUBZONE}.${ZONE}"
fi

logit() {
    # Function to log script output

    local LOG_LEVEL="${1}"
    shift
    local MSG="${*}"
    local TIMESTAMP=$(date +"%d-%m-%Y %T")
    if ${VERBOSE}; then
        echo "${TIMESTAMP} ${HOSTNAME} $(basename ${0}) : ${MSG}" | tee -a "${LOG_FILE}"
    elif [[ "${LOG_LEVEL}" = 'ERROR' || "${LOG_LEVEL}" = 'DEF' ]]; then
        echo "${TIMESTAMP} ${HOSTNAME} $(basename ${0}) : ${MSG}" | tee -a "${LOG_FILE}"
    fi

}

usage() {
# Help user on script usage

printf "\
%-s\n\
%-s\n\n\
%-s\n\
%-5s %-15s%-5s%-s\n\
%-5s %-15s%-5s%-s\n\
%-26s%-s\n\
%-26s%-s\n\
%-5s %-15s%-5s%-s\n\
%-5s %-15s%-5s%-s\n\
" \
"Usage: $(basename ${0}) [-vh] [-l] [ARG]" \
"Note: Running the script without any option(s) will print only error message(s) and/or final script output." \
"Options:" \
"-v" "verbose mode" "-" "Show every action performed by the script." \
"-l" "[log path]" "-" "Write the output to a file. If [log path] not specified, current directory is used." \
"" "with [log path] specified, output is written to that path." \
"" "Specify only /path/to/dir , filename is automatically filled in format: 'cddns_DDMMYY_HHMM.log'" \
"-f" "forced mode" "-" "If DNS record type indicated by user doesn't match with the one on Cloudflare ('A' <-> 'AAAA'), using '-f' will overwrite it." \
"-h" "help" "-" "Shows this help and exit."

}

# Parse input from user
while getopts vlfh OPTION; do
    case ${OPTION} in
        v) VERBOSE=true ;;
        l) CREATE_LOG=true ;;
        f) FORCED=true ;;
        h) usage; exit 0 ;;
        *) usage; exit 1 ;;
    esac
done

shift "$(( OPTIND - 1 ))" # make sure only argumens are left, no options

#################
# Sanity checks #
#################

# Check user input for log file
if ${CREATE_LOG}; then
    if [[ "${#}" -lt 1 ]]; then
        LOG_PATH="$(dirname ${0})" # log file will be placed in same directory as script
        LOG_FILE="${LOG_PATH}/${LOG_NAME}"
    else
        LOG_PATH="${@}"
        LOG_FILE="${LOG_PATH}/${LOG_NAME}"
        if ! [[ -w "${LOG_PATH}" && -d "${LOG_PATH}" ]]; then
            echo "ERROR: Chosen path either not a directory or is not writable by you: '${LOG_PATH}'" 
            exit 1
        fi
    fi
    echo "Outputting to log file: ${LOG_FILE}"
else
    LOG_FILE='/dev/null'
fi

# Create header if verbose is selected
if ${VERBOSE}; then
    H_TXT="$(date '+%d-%b-%Y / %H:%M') - Starting $(basename ${0})"
    H_LEN="${#H_TXT}"
    logit DEF "$(for i in $(seq ${H_LEN}); do printf '#';done)"
    logit DEF "${H_TXT}"
    logit DEF "$(for i in $(seq ${H_LEN}); do printf '#';done)"
    ${FORCED} && logit DEF "!!! FORCED MODE ENABLED !!! --> records will be overwritten even if they don't match!"
fi

# Check for required commands to be available
logit INFO "Checking for required commands to be installed."

REQ=("dirname" "curl" "expr" "date") # required installed commands

# If some required commands not found on system, store them in MIS
for i in ${!REQ[@]}; do
    if ! type ${REQ[$i]} &> /dev/null; then
        MIS+=("${REQ[$i]}")
    fi
done

# If MIS created, means that some required commands not installed. Inform user and exit
if (( ${MIS+1} )); then
    logit ERROR "ERROR: One or more required commands not found on system: '${MIS[@]}'" >&2
    logit ERROR "Install them and retry the script." >&2
    exit 1
else
    logit INFO "All required commands are installed."
fi

# Check if all mandatory variables were filled in correctly
logit INFO "Checking validity for mandatory variables."

if [[ -z ${API} || -z ${E_MAIL} || -z ${ZONE} || -z ${PROXIED} || -z ${TYPE} || -z ${TTL} ]]; then
    logit ERROR "ERROR: One or more mandatory variables are empty." >&2
    exit 1
elif ! [[ ${PROXIED} = 'true' || ${PROXIED} = 'false' ]]; then
    logit ERROR "ERROR: PROXIED value is wrong. Must be either 'true' or 'false'" >&2
    exit 1
elif ! [[ ${TTL} -ge 60 && ${TTL} -le 86400 ]] &> /dev/null && ! [[ ${TTL} -eq 1 ]] &> /dev/null; then
    logit ERROR "ERROR: TTL value is wrong. Must be either 1 or between 60 and 86400." >&2
    exit 1
else
    logit INFO "All required variables filled in and valid."
fi

# Check e-mail address validity
logit INFO "Check e-mail address validity."
if ! echo ${E_MAIL} | grep -q -P "(^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$)"; then
    logit ERROR "ERROR: Wrong format for e-mail address. Please check."
    exit 1
else
    logit INFO "e-mail address seems valid."
fi

# Check internet connectivity
logit INFO "Checking if internet connection is up and runinng..."

if ! $(ping -c1 8.8.8.8 &> /dev/null || ping -c1 1.1.1.1 &> /dev/null); then
    logit ERROR "ERROR: Seems that we are not connected to the internet." >&2
    exit 1
else
    logit INFO "We are connected to the internet."
fi

# Check API key
logit INFO "Checking API token validity..."
VERIFY_TOKEN_URL="'${ENDPOINT}user/tokens/verify'"
VERIFY_TOKEN_COM="${GET} ${VERIFY_TOKEN_URL} ${AUTH}"

if ! $(eval "${VERIFY_TOKEN_COM}" | grep -q '"success":true'); then
    logit ERROR "ERROR: API token verification failed. Check API token value." >&2
    exit 1
else
    logit INFO "API token seems valid."
fi

# Check systems public IPv4 and IPv6 IPs
logit INFO "Check systems public IPv4 and IPv6 IPs."
for IP in IPv4 IPv6; do
    logit INFO "Checking for ${IP}..."
    eval ${IP}="$(curl -s -X GET -${IP:(-1)} https://ifconfig.co || curl -s -X GET -${IP:(-1)}  https://icanhazip.com)"
    if [[ -n ${!IP} ]]; then 
        logit INFO "Found: ${!IP}"
    else 
        logit INFO "No ${IP} detected."
    fi
done

# Check TYPE variable
logit INFO "Checking user specified DNS record type to update."

case ${TYPE} in
       A) IP=${IPv4} 
          logit INFO "DNS Record type 'A' detected."
          ;;
    AAAA) #IP=${IPv6}
          IP='2806:1016:c:a1a6:73a2:d0a6:d8c8:a2a3'
          logit INFO "DNS Record type 'AAAA' detected."
          ;;
       *) logit ERROR "ERROR: TYPE value is wrong: '${TYPE}'. Must be either 'A' or 'AAAA'" >&2; exit 1 ;;
esac

# If IP empty, means that DNS record type selected not present on system
if [[ -z ${IP} ]]; then 
    logit ERROR "ERROR: User selected DNS record type: '${TYPE}' but this type of IP is not present on system." >&2
    exit 1
fi

#################
# Actual script #
#################

# Obtain zone identifier
logit INFO "Retrieving ZONE ID from Cloudflare..."

ZONE_ID_URL="'${ENDPOINT}zones?name=${ZONE}&status=active'"
ZONE_ID_COM="${GET} ${ZONE_ID_URL} ${HEADERS}"
ZONE_ID=$(eval "${ZONE_ID_COM}" | grep -o -P '(?<=\[{"id":").+?(?=","name":)')

if [[ -n ${ZONE_ID} ]]; then
    logit INFO "ZONE ID found: ${ZONE_ID}"
else
    logit ERROR "ERROR: ZONE ID could not be retrieved! Check user variables." >&2
    exit 1
fi

# Obtain DNS record ID and IP
logit INFO "Retrieving DNS record ID and IP for sub-domain ${RECORD} from Cloudflare..."

DNS_RECORD_URL="'${ENDPOINT}zones/${ZONE_ID}/dns_records?name=${RECORD}'"
DNS_RECORD_COM="${GET} ${DNS_RECORD_URL} ${HEADERS}"
DNS_RECORD_ID=$(eval "${DNS_RECORD_COM}" | grep -o -P '(?<="id":").+?(?=",")')
DNS_RECORD_IP=$(eval "${DNS_RECORD_COM}" | grep -o -P '(?<="content":").+?(?=","proxiable")')
DNS_RECORD_TYPE=$(eval "${DNS_RECORD_COM}" | grep -o -P '(?<="type":").+?(?=","content")')

if [[ -n ${DNS_RECORD_ID} ]]; then
    logit INFO "DNS record ID found: ${DNS_RECORD_ID}"
else
    logit ERROR "ERROR: DNS record ID could not be retrieved for sub-domain '${RECORD}'!" >&2
    exit 1
fi

if [[ -n ${DNS_RECORD_IP} ]]; then
    logit INFO "DNS record IP found: ${DNS_RECORD_IP}"
else
    logit ERROR "ERROR: DNS record IP could not be retrieved for sub-domain '${RECORD}'!" >&2
    exit 1
fi

# Check if user selected DNS record type matches the one already on Cloudflare
${FORCED} || if [[ "${TYPE}" != "${DNS_RECORD_TYPE}" ]]; then
    logit ERROR "ERROR: User selected DNS record type: '${TYPE}' doesn't match Cloudflare DNS record type: '${DNS_RECORD_TYPE}'" >&2
    logit ERROR "ERROR: Use '-f' option to force override: '${0} -f'" >&2
    exit 1
fi

# Check systems IP and DNS record IP
logit INFO "Check systems IP vs. DNS record IP for ${RECORD} on Cloudflare"

if [[ ${IP} != ${DNS_RECORD_IP} ]]; then
    logit INFO "Systems IP: ${IP} does not match DNS record IP on Cloudflare: ${DNS_RECORD_IP} Initializing IP update."
    
    # Building command for IP update
    PUT_URL="'${ENDPOINT}zones/${ZONE_ID}/dns_records/${DNS_RECORD_ID}'"
    PUT_DATA="--data '{\"type\":\"${TYPE}\",\"name\":\"${RECORD}\",\"content\":\"${IP}\",\"ttl\":${TTL},\"proxied\":${PROXIED}}'"
    PUT_COM="${PUT} ${PUT_URL} ${HEADERS} ${PUT_DATA}"

    # Update IP
    eval ${PUT_COM} &> /dev/null

    logit DEF "IP update successfull"
else
    logit DEF "Systems IP and DNS record IP on Cloudflare match ${IP} No update required."
    exit 0
fi

# If reached this step, provide an adequate error code
exit 0
