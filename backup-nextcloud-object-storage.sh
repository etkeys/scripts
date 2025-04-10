#!/usr/bin/env bash

#*************************************************************************
# Use b2 to sync nextcloud object storage data to a local drive
#*************************************************************************

set -e

export HOME='/home/erik'

MOUNT_POINT="${S3_BACKUP_MOUNT_POINT:=/mnt/erik/obj-store-bak}"
B2_APP="$HOME/.local/bin/b2"

function write_message(){
    echo "$(date '+%F %T') $1"
}

DIRECTORIES=('Documents' 'Music' 'Pictures' 'Videos')

for DIRECTORY in "${DIRECTORIES[@]}"; do
    write_message "Syncing ${DIRECTORY}..."

    DEST="${MOUNT_POINT}/nextcloud/${DIRECTORY}"
    [ ! -d "${DEST}" ] && mkdir -p "${DEST}"
    "$B2_APP" sync \
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
