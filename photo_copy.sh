#!/bin/bash
# Title             :    photo_copy.sh
# Description       :    Copy N random photos from a local folder to a cloud folder
# Author            :    gvdn
# E-Mail            :    contact@gvdn.cz
# Creation Date     :    22-November-2021
# Latest Update     :    N/A
# Version           :    0.1
# Usage             :    ./photo_sync.sh
# Notes             :    rclone needs to be installed and configured
# Bash Version      :    5.0.3(1)-release

# Long description:

# The script will take N number of photos from a local directory and copy it to a remote one (OneDrive, Google Drive, etc)
# Old photos present on the remote location will be deleted and replaced with the new ones
# Possible use cases: devices which work as digital photo frames

# ====================================================================================================

##########################
# User defined variables #
##########################

PHOTO_DIR='/mnt/tablet_photos/george/files/Photos' # local directory where to take the photos from
REMOTE_NAME='tableta' # name for the cloud remote which was chosen during rclone config
REMOTE_DIR='plm' # desired name for the folder on the remote cloud location where the photos will be copied to
N_PIC='23' # number of pics to shufle

##################################
# Script variables and functions #
##################################

# Build the full remote path
REM="${REMOTE_NAME}:${REMOTE_DIR}"

log() {
    # Function to print script output

    local MSG="${*}"
    local TIMESTAMP=$(date +"%d-%m-%Y %T")
    echo "${TIMESTAMP} ${HOSTNAME} $(basename ${0}) : ${MSG}"

}

#################
# Sanity checks #
#################

# Specify for which programs / commands to look for
log "Checking if required commands / programms are installed"
REQ=("rclone" "basename" "xargs" "shuf") # required installed commands 

# If some required commands not found on system, store them in MIS
for i in ${!REQ[@]}; do
    if ! type ${REQ[$i]} &> /dev/null; then
        MIS+=("${REQ[$i]}")
    fi
done

# If MIS created, means that some required commands not installed. Inform user and exit
if (( ${MIS+1} )); then
    log "ERROR: One or more required commands not found on system: '${MIS[@]}'" >&2
    log "ERROR: Install them and retry the script." >&2
    exit 1
else
    log "All required commands are installed."
fi

# check if rclone has at least one remote
if [[ -z "$(rclone listremotes)" ]]; then
    log "ERROR: No remotes found on rclone. Make sure is set-up correctly." >&2
    exit 1
fi


# Check if remote name exists
if ! rclone lsd ${REMOTE_NAME}: &> /dev/null; then
    log "ERROR: Remote name not valid: '${REMOTE_NAME}', please check your input." >&2
    exit 1
fi

#################
# Actual script #
#################
# Create remote folder for photos if not exist
if ! rclone lsd "${REM}" &> /dev/null; then
    log "Creating remote folder for photos."
    rclone mkdir "${REM}"
fi


# Create array for old photos present on remote
log "Storring photo names currently present on remote."
while read -r OLD_PHOTO;
do
	arrOLD_PHOTOS=("${arrOLD_PHOTOS[@]}" "$OLD_PHOTO");
done <<< "$(rclone lsf ${REM})"

# Copy N new photos to remote
log "Start copying ${N_PIC} new photos from local to remote."
find "${PHOTO_DIR}" -type f | shuf -n ${N_PIC} | while read NEW_PHOTO; do
    log "Copying ${NEW_PHOTO} to ${REM}"
    rclone copy "${NEW_PHOTO}" "${REM}"
    printf "Done"
done

# Delete old photos from remote
log "Deleting old photos on cloud ${REM}"
for i in "${arrOLD_PHOTOS[@]}";
do 
	rclone deletefile "${REM}"/"$i"
done
