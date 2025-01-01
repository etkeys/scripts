#!/bin/bash

#*************************************************************************
# Use awscli to sync nextcloud object storage data to a local drive
#*************************************************************************

set -e

ENDPOINT="${S3_ENDPOINT:?Nextcloud s3 endpoint not set}"
MOUNT_POINT="${S3_BACKUP_MOUNT_POINT:=/mnt/erik/obj-store-bak}"

function write_message(){
    echo "$(date '+%F %T') $1"
}

DIRECTORIES=('Documents' 'Music' 'Pictures' 'Videos')

for DIRECTORY in "${DIRECTORIES[@]}"; do
    write_message "Syncing ${DIRECTORY}..."

    DEST="${MOUNT_POINT}/nextcloud/${DIRECTORY}"
    [ ! -d "${DEST}" ] && mkdir -p "${DEST}"
    aws s3 sync \
        "s3://etkeys-objs001-erik-${DIRECTORY}/" \
        "${DEST}/." \
        --endpoint="${ENDPOINT}" \
        --delete \
        --no-progress \
        --output text
done

cat << EOF > "${MOUNT_POINT}/nextcloud/last-sync.txt"
$(date)
"${ENDPOINT}"
EOF

write_message "Done."