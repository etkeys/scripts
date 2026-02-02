#!/usr/bin/env bash

ID="${BACKUP_VM_LXC_ID:?"Environment variable BACKUP_VM_LXC_ID is not set. It should contain the VM or LXC ID to check for backups."}"

BACKUP_DIR_ROOT="/vmpool/backups"

if [ ! -d "$BACKUP_DIR_ROOT" ]; then
    echo "Error: Backup directory root $BACKUP_DIR_ROOT does not exist."
    exit 1
fi


if [ ! -d "$BACKUP_DIR_ROOT/$ID" ]; then
    echo "Error: Directory $BACKUP_DIR_ROOT/$ID does not exist."
    exit 1
fi

FILE_FULLNAME=$(ls -1t "$BACKUP_DIR_ROOT/$ID"/*.zst | head -n 1)
if [ -z "$FILE_FULLNAME" ]; then
    echo "Error: No backup files found for VM/LXC ID $ID in $BACKUP_DIR_ROOT/$ID."
    exit 1
fi

FILENAME=$(basename "$FILE_FULLNAME")
echo $FILENAME