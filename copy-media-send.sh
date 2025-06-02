#!/usr/bin/env bash

set -e

SOURCE_DIR="${HOME}/Videos/rip/send"
DESTINATION_DIR="media002:/media/media-share"

rsync \
    --recursive \
    --times \
    --whole-file \
    --progress \
    "${SOURCE_DIR}/." \
    "${DESTINATION_DIR}/."
