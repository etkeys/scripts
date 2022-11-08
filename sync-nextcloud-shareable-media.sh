#!/usr/bin/env bash

set -e

NEXTCLOUD_S3_ENDPOINT="${NEXTCLOUD_S3_ENDPOINT:?Nextcloud s3 enpoint not set}"
NEXTCLOUD_S3_BUCKET="s3://etkeys-nextcloud-erik-media"

aws s3 sync \
    "${NEXTCLOUD_S3_BUCKET}/Music" \
    Music/. \
    --exclude "AudioBooks/*" \
    --exclude "Ringtones/*" \
    --exclude "Sound bites/*" \
    --endpoint="${NEXTCLOUD_S3_ENDPOINT}" \
    --delete

aws s3 sync \
    "${NEXTCLOUD_S3_BUCKET}/Videos" \
    Videos/. \
    --endpoint="${NEXTCLOUD_S3_ENDPOINT}" \
    --delete

