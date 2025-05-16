#!/usr/bin/env bash

#*************************************************************************
# Use b2 to sync nextcloud object storage data to a local drive
#*************************************************************************

set -e

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

write_message "Done."
