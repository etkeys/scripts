#!/usr/bin/env bash

#*************************************************************************
# Use awscli to sync media store contents with object storage.
#*************************************************************************

set -e

S3_ENDPOINT="${S3_ENDPOINT:?S3 endpoint not provided}"
MOUNT_POINT="${MEDIA_STORE_MOINT_POINT:=/media/media-store}"

# Sync items from local storage to object storage
# The source of turth for these items is the local storage and we want
# object storage to be a copy.
aws s3 sync \
    "${MOUNT_POINT}/movies/" \
    "s3://etkeys-movies-and-series/movies" \
    --endpoint "${S3_ENDPOINT}" \
    --delete \
    --no-progress \
    --output text

aws s3 sync \
    "${MOUNT_POINT}/series/" \
    "s3://etkeys-movies-and-series/series" \
    --endpoint "${S3_ENDPOINT}" \
    --delete \
    --no-progress \
    --output text

# Sync items from object storage to local storage
# The source of turth for these items is object storage and we want
# local storage to be a copy.
# Music bucket needs to be reorganized disabling for now.
# aws s3 sync \
#     "s3://etkeys-nextcloud-media/music" \
#     "${MOUNT_POINT}/music/" \
#     --endpoint "${S3_ENDPOINT}" \
#     --delete \
#     --no-progress \
#     --output text

cat << EOF > "${MOUNT_POINT}/last-sync.txt"
$(date)
"${S3_ENDPOINT}
EOF
