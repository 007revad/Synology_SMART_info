#!/bin/bash

# Download and update installed syno_smart_info

set -Eeuo pipefail

FILENAME="syno_smart_info.sh"
TMP_FILENAME="/tmp/$FILENAME"

function err() {
   local rc="$1"
   echo "??? Unexpected error occured with RC $rc"
   local i=0
   local FRAMES=${#BASH_LINENO[@]}
   for ((i=FRAMES-2; i>=0; i--)); do
      echo '  File' \"${BASH_SOURCE[i+1]}\", line ${BASH_LINENO[i]}, in ${FUNCNAME[i+1]}
      sed -n "${BASH_LINENO[i]}{s/^/    /;p}" "${BASH_SOURCE[i+1]}"
   done
}

function cleanup() {
    local rc=$1
    rm "$TMP_FILENAME" &>/dev/null || true
    (( $rc )) && { echo "??? $FILENAME updated failed"; exit 1; } || { echo "--- $FILENAME updated successfully"; exit 0; }
}

# *** MAIN ***

trap 'cleanup $?' SIGINT SIGTERM SIGHUP EXIT
trap 'err $?' ERR

if (( $# == 1 )); then
    INSTALL_DIR="$1"
    INSTALL_FILENAME="${INSTALL_DIR}/${FILENAME}"
    if [[ ! -f $INSTALL_FILENAME ]]; then
        echo "??? $INSTALL_FILENAME not found"
        exit 1
    fi
elif ! INSTALL_FILENAME=$(which $FILENAME); then
    echo "??? $FILENAME not found"
    echo "--- Pass the installation directory as argument"
    exit 1
fi

set +e
echo "--- Downloading $FILENAME into $TMP_FILENAME ..."
wget -q https://raw.githubusercontent.com/007revad/Synology_SMART_info/refs/heads/main/$FILENAME -O $TMP_FILENAME
(( $? )) && { echo "??? wget failed"; exit 1; }

chmod 755 $TMP_FILENAME
(( $? )) && { echo "??? chmod failed"; exit 1; }

echo "--- Creating backup of $FILENAME ..."
cp $INSTALL_FILENAME ${INSTALL_FILENAME}.bak
(( $? )) && { echo "??? cp failed"; exit 1; }

echo "--- Moving $TMP_FILENAME into $INSTALL_FILENAME ..."
mv $TMP_FILENAME $INSTALL_FILENAME
(( $? )) && { echo "??? mv failed"; exit 1; }
set -e

$INSTALL_FILENAME -v
