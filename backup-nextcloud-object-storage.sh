#!/bin/bash

#*************************************************************************
# Use awscli to sync nextcloud object storage data to a local drive
#*************************************************************************

set -e

NEXTCLOUD_S3_ENDPOINT="${NEXTCLOUD_S3_ENDPOINT:?Nextcloud s3 endpoint not set}"
MOUNT_POINT="${S3_BACKUP_MOUNT_POINT:=/home/erik/nextcloud_backup}"

declare -A roots
roots[erik]="etkeys-nextcloud-erik"

for LOCAL_ROOT in "${!roots[@]}"; do
    DEST="${MOUNT_POINT}/${LOCAL_ROOT}"

    [ ! -d "${DEST}" ] && mkdir "${DEST}"

    aws s3 sync \
        "s3://${roots[$LOCAL_ROOT]}/" \
        "${DEST}/." \
        --endpoint="${NEXTCLOUD_S3_ENDPOINT}" \
        --delete
done

cat << EOF > "${MOUNT_POINT}/last-sync.txt"
$(date)
"${NEXTCLOUD_S3_ENDPOINT}"
EOF

