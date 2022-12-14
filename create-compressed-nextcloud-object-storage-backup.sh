#!/usr/bin/env bash

set -e

DATESTAMP=$(date "+%F") # like: 2022-08-27
NEXTCLOUD_BACKUP_ID=/home/erik/nextcloud_backup_id
NEXTCLOUD_BACKUP_OD=/home/erik/nextcloud_backup_od

if [ $# -gt 1 ]; then
    while [ $# -gt 0 ]; do
        case "${1}" in
            --id)
                shift;
                NEXTCLOUD_BACKUP_ID="${1}"
                shift;;
            --od)
                shift;
                NEXTCLOUD_BACKUP_OD="${1}"
                shift;;
        esac
    done
fi

if [ ! -e "${NEXTCLOUD_BACKUP_ID}" ]; then
    echo "Input directory '${NEXTCLOUD_BACKUP_ID}' does not exist!"
    exit 1
fi

if [ ! -e "${NEXTCLOUD_BACKUP_OD}" ]; then
    echo "Output directory '${NEXTCLOUD_BACKUP_OD}' does not exist!"
    exit 1
fi


time tar -cv --zstd -f "${NEXTCLOUD_BACKUP_OD}/${DATESTAMP}.tar.zstd" "${NEXTCLOUD_BACKUP_ID}/."

