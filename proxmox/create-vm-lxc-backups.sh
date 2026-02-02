#!/usr/bin/env bash

# check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

BACKUP_DIR_ROOT="/vmpool/backups"
KEEP_BACKUPS=${KEEP_BACKUPS:-7}  # default to 7 days if not set

# read items to backup from environment variable
IFS=',' read -r -a items_to_backup <<< "$ITEMS_TO_BACKUP"

# exit if backup directory root does not exist
if [ ! -d "$BACKUP_DIR_ROOT" ]; then
    echo "Backup directory root does not exist: $BACKUP_DIR_ROOT"
    exit 1
fi

#set umask to ensure correct permissions on created files
umask 027

HAS_ERROR=0

# for each item...
for item in "${items_to_backup[@]}"; do
    # create backup directory for item if it doesn't exist
    backup_dir="${BACKUP_DIR_ROOT}/${item}"
    if [ ! -d "$backup_dir" ]; then
        echo "Creating backup directory: $backup_dir"
        mkdir -p "$backup_dir"
    fi

    echo "Creating backup for VM/LXC container: $item"
    vzdump "$item" --dumpdir "$backup_dir" --mode snapshot --compress zstd --quiet 1
    if [ $? -eq 0 ]; then
        echo "Backup for VM/LXC container $item created successfully."

        # delete old backups, printing what is being deleted
        echo "Deleting older backups for $item (keeping last $KEEP_BACKUPS backups)."

        ls -1t "${backup_dir}/"*.zst 2>/dev/null |
        tail -n +$((KEEP_BACKUPS + 1)) |
        while read -r old_backup; do
            echo "Deleting old backup: $old_backup"
            rm -f "$old_backup"
        done

        ls -1t "${backup_dir}/"*.log 2>/dev/null |
        tail -n +$((KEEP_BACKUPS + 1)) |
        while read -r old_backup; do
            echo "Deleting old log: $old_backup"
            rm -f "$old_backup"
        done
    else
        echo "Failed to create backup for VM/LXC container $item."
        HAS_ERROR=1
    fi

done

if [ $HAS_ERROR -eq 1 ]; then
    echo "One or more backups failed."
    exit 1
else
    echo "All backups created successfully."
    exit 0
fi