#!/usr/bin/env bash

#*************************************************************************
# Use b2 to sync media store contents with object storage.
#*************************************************************************

set -e

# export HOME='/home/erik'
MOUNT_POINT="${MEDIA_STORE_MOINT_POINT:=/media/media-share}"
#B2_APP="$HOME/.local/bin/b2"

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

# Sync items from local storage to object storage
# The source of turth for these items is the local storage and we want
# object storage to be a copy.

write_message "Syncing Movies..."

# "$B2_APP" \
b2 \
    sync \
    "${MOUNT_POINT}/movies/" \
    "b2://etkeys-movies-and-series/movies" \
    --skip-newer \
    --delete \
    --no-progress \
    --dry-run

write_message "Syncing Series..."

# "$B2_APP" \
b2 \
    sync \
    "${MOUNT_POINT}/series/" \
    "b2://etkeys-movies-and-series/series" \
    --skip-newer \
    --delete \
    --no-progress \
    --dry-run

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

write_message "Done."
