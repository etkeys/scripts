#!/usr/bin/env bash
# Copy files from a remote ZFS snapshot to a local directory (on external disk)
# using rsync. The zfs snapshot is determined by the latest snapshot of the
# specified dataset. The script can perform either a full backup or an
# incremental backup based on the last backup.

DESTINATION_DIR_ROOT="${HOME}/nas_backup"
DESTINATION_DIR_SUFFIX="full-backup"
INCREMENTAL=0
SOURCE_DATASET="tank/heap_erik"
SSH_HOST="media002"



SOURCE_DATASET_MOUNT_POINT="$(ssh ${SSH_HOST} zfs get -Ho value mountpoint ${SOURCE_DATASET})"

SNAPSHOT_NAME="$(
ssh ${SSH_HOST} zfs list -t snapshot -o name ${SOURCE_DATASET} |
    tail -n 1 |
    cut -d '@' -f 2)"

SOURCE_DIR="${SOURCE_DATASET_MOUNT_POINT}/.zfs/snapshot/${SNAPSHOT_NAME}"

INCREMENTAL_SOURCE_DIR="$(
find "${DESTINATION_DIR_ROOT}" -maxdepth 1 -type d -not -name "lost+found" |
    sort |
    tail -n 1 |
    cut -d '/' -f 2)"

read -r -p "Do you want to do an incremental backup based on ${INCREMENTAL_SOURCE_DIR}? (y/n) " REPLY
if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    INCREMENTAL=1
    DESTINATION_DIR_SUFFIX="incremental-backup"
fi


DESTINATION_DIR="${DESTINATION_DIR_ROOT}/${SNAPSHOT_NAME}-${DESTINATION_DIR_SUFFIX}"
if [ -d "${DESTINATION_DIR}" ]; then
    echo "Destination directory, '${DESTINATION_DIR}', already exists. Exiting."
    exit 1
fi

mkdir "${DESTINATION_DIR}"

if [ "${INCREMENTAL}" -eq 1 ]; then
    echo "Incremental backup based on ${INCREMENTAL_SOURCE_DIR}"

    time \
    rsync -av \
        --progress \
        --delete \
        --link-dest="${DESTINATION_DIR_ROOT}/${INCREMENTAL_SOURCE_DIR}" \
        "${SSH_HOST}:${SOURCE_DIR}/." \
        "${DESTINATION_DIR}/."
else
    echo "Full backup"

    time \
    rsync -av \
        --progress \
        "${SSH_HOST}:${SOURCE_DIR}/." \
        "${DESTINATION_DIR}/."
fi

