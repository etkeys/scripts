#!/usr/bin/env bash

#*************************************************************************
# Use b2 to sync nextcloud object storage data to a local drive
#*************************************************************************

set -e
set -u

MOUNT_POINT="${S3_BACKUP_MOUNT_POINT:=/mnt/erik/heap}"

LOG_WITH_TIMESTAMP=0
for arg in "$@"; do
    if [[ "$arg" == "--log-omit-timestamp" ]]; then
        LOG_WITH_TIMESTAMP=1
        break
    fi
done

function write_message(){
    if [[ $LOG_WITH_TIMESTAMP -eq 0 ]]; then
        echo "$(date '+%F %T') $1"
    else
        echo "$1"
    fi
}

DIRECTORIES=('Documents' 'Music' 'Pictures' 'Videos')

function check_for_folder_placeholders {
    local FOUND_PROBLEMS=false
    local DIRECTORY
    for DIRECTORY in "${DIRECTORIES[@]}"; do
        local TEXT
        TEXT=$(
            b2 ls \
                "b2://etkeys-objs001-erik-${DIRECTORY}/*/" \
                --recursive \
                --with-wildcard |
            sort
        )
        if [ $? -ne 0 ]; then
            write_message "Error checking for folder placeholders in ${DIRECTORY}."
            exit 1
        fi
        if [[ "${DIRECTORY}" == "Documents" ]]; then
            # the JoplinNotes/locks/ folder is a placeholder is allowed to have an
            # empty folder

            # Need to have the set +e here to not exit the script if the grep fails
            # because the grep will fail if there are no matches
            set +e
            TEXT=$(echo "${TEXT}" | grep -vx 'JoplinNotes/locks/')
            set -e
        fi
        if [ -n "${TEXT}" ]; then
            write_message "Found folder placeholders in ${DIRECTORY}."
            write_message "${TEXT}"
            FOUND_PROBLEMS=true
        fi
    done

    if [ "${FOUND_PROBLEMS}" = true ]; then
        write_message "Please remove the folder placeholders."
        exit 1
    fi
}

function do_sync {
    for DIRECTORY in "${DIRECTORIES[@]}"; do
        write_message "Syncing ${DIRECTORY}..."

        DEST="${MOUNT_POINT}/nextcloud/${DIRECTORY}"
        [ ! -d "${DEST}" ] && mkdir -p "${DEST}"
        b2 sync \
            "b2://etkeys-objs001-erik-${DIRECTORY}/" \
            "${DEST}/." \
            --delete \
            --replace-newer \
            --no-progress
    done

cat << EOF > "${MOUNT_POINT}/nextcloud/last-sync.txt"
$(date)
EOF
}

write_message "Checking for folder placeholders..."
check_for_folder_placeholders
write_message "Syncing Nextcloud object storage to ${MOUNT_POINT}..."
do_sync
write_message "Done."
