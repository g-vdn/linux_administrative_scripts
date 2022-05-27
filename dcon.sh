#!/bin/bash
# Title             :    dcon.sh
# Description       :    Connect to a docker bash
# Author            :    gvdn
# E-Mail            :    contact@gvdn.cz
# Creation Date     :    27-May-2022
# Latest Update     :    N/A
# Version           :    1
# Usage             :    ./docker_connect.sh
# Notes             :    N/A
# Bash Version      :    5.0.3(1)-release
# ====================================================================================================

# Set the PS3 a.k.a. question line
PS3='Choose the docker you want to connect to: ' 


# Create array with all running dockers
for i in $(docker ps |awk '{print $NF}' | grep -v "NAMES" | grep -v "portainer"); do DOCKS=("${DOCKS[@]}" "${i}");done

# Add exit option
DOCKS=("${DOCKS[@]}" "Exit")

# List the docker and connect connect to them
select DOCK in "${DOCKS[@]}"; do
	if [[ ${DOCK} = "Exit" ]]; then exit 0;fi
	docker exec -it "${DOCK}" bash
	exit 0
done
