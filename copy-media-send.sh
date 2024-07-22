#!/usr/bin/env bash

set -e

MEDIA_SEND_ROOT="${HOME}/Videos/rip"
MEDIA_SEND_DIR="${MEDIA_SEND_ROOT}/send"
MEDIA_REVIEW_DIR="${MEDIA_SEND_ROOT}/review"

rsync \
    --recursive \
    --checksum \
    --itemize-changes \
    --times \
    --whole-file \
    --progress \
    "${MEDIA_SEND_DIR}/." \
    media001:/media/media-store/.

[[ -d "${MEDIA_SEND_DIR}/movies" ]] && mv "${MEDIA_SEND_DIR}"/movies/* "${MEDIA_REVIEW_DIR}/"

[[ -d "${MEDIA_SEND_DIR}/series" ]] && mv "${MEDIA_SEND_DIR}"/series/* "${MEDIA_REVIEW_DIR}/"
