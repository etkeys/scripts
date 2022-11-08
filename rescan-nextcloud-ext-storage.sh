#!/usr/bin/env bash

set -e

PATHS=('/erik/files/ext-erik' '/erik/files/ext-erik/media')

for p in "${PATHS[@]}"; do
    docker exec -it nextcloud-aio-nextcloud php occ files:scan -vvv -path "${p}"
done

