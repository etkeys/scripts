#!/usr/bin/env bash

set -e

SOURCE_DIR="${HOME}/Videos/rip/send"
DESTINATION_DIR="nas001:/mnt/naspool/media_share"

rsync \
    --recursive \
    --times \
    --whole-file \
    --progress \
    "${SOURCE_DIR}/." \
    "${DESTINATION_DIR}/."
