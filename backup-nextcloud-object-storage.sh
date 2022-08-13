#!/bin/bash

#************************************************************************
# Use awscli to sync nextcloud object storage data to a local drive
#************************************************************************

set -e

S3_END_POINT="${S3_BACKUP_END_POINT:-https://us-east-1.linodeobjects.com}"
MOUNT_POINT="${S3_BACKUP_MOUNT_POINT:=/home/erik/nextcloud_backup}"

declare -A roots
roots[erik]="etkeys-nextcloud"

for LOCAL_ROOT in "${!roots[@]}"; do
    DEST="${MOUNT_POINT}/${LOCAL_ROOT}"

    [ ! -d "${DEST}" ] && mkdir "${DEST}"

    aws s3 sync \
        "s3://${roots[$LOCAL_ROOT]}" \
        "${DEST}/." \
        --endpoint="${S3_END_POINT}" \
        --delete
done

date > "${MOUNT_POINT}/last-sync.txt"

