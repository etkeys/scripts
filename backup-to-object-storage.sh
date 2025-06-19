#!/usr/bin/env bash

# Backup to Object Storage Script
#
# This script performs automated backups to object storage using Backblaze B2
# by processing multiple configuration files for different backup paths.
#
# Features:
# - Supports multiple backup configurations in a single directory
# - Validates configuration before sync
# - Uses B2 CLI for object storage synchronization
# - Provides error handling and reporting
#
# Prerequisites:
# - Backblaze B2 CLI (b2) must be installed
# - B2 account credentials must be configured. Location of credentials database
#   must be defined in the B2_ACCOUNT_INFO environment variable BEFORE running
#   this script.
# - Encryption key file must be base64 encoded and located at:
#   /home/erik/secrets/b2_sync_default.key
# - Configuration files located in /usr/local/etc/backup-to-object-storage.d/
# - Each configuration file must define:
#   * LOCAL_PATH: Source directory to backup
#   * DESTINATION_BUCKET_PATH: Target B2 bucket path
#   * OPTIONS: (optional) for additional b2 sync parameters, must be quoted
#
# Usage:
#   ./backup-to-object-storage.sh
#
# Exit Codes:
# - 1: Configuration directory does not exist
# - 2: Encryption key file does not exist
# - 100: One or more sync operations failed

set -e

CONFIG_DIR="/usr/local/etc/backup-to-object-storage.d"
ENCRYPTION_KEY_FILE="/home/erik/secrets/b2_sync_default.key" # contents must be base64 encoded

if [ ! -e "$CONFIG_DIR" ]; then
    echo "Error: Configuration directory $CONFIG_DIR does not exist"
    exit 1
fi

if [ ! -e "$ENCRYPTION_KEY_FILE" ]; then
    echo "Error: Encryption key file $ENCRYPTION_KEY_FILE does not exist"
    exit 1
fi

export B2_DESTINATION_SSE_C_KEY_B64=$(cat "$ENCRYPTION_KEY_FILE")
export B2_ACCOUNT_INFO

HAS_FAILURE=false
for config_file in "$CONFIG_DIR"/*.conf; do
    # Skip if not a file
    [ -f "$config_file" ] || continue

    OPTIONS=""

    # Get the base filename (service name)
    source "$config_file"

    # Validate required variables
    if [ -z "$LOCAL_PATH" ] || [ -z "$DESTINATION_BUCKET_PATH" ]; then
        echo "Error: LOCAL_PATH or DESTINATION_BUCKET_PATH not set in $config_file"
        HAS_FAILURE=true
        continue
    fi

    # Execute the sync
    echo "Syncing $LOCAL_PATH to $DESTINATION_BUCKET_PATH..."
    # shellcheck disable=SC2086
    b2 sync --threads 2 $OPTIONS "$LOCAL_PATH" "$DESTINATION_BUCKET_PATH"

    if [ $? -ne 0 ]; then
        echo "Error: Sync failed for $LOCAL_PATH to $DESTINATION_BUCKET_PATH"
        HAS_FAILURE=true
    fi

    echo "Sync completed successfully for $LOCAL_PATH to $DESTINATION_BUCKET_PATH"
done

if [ "$HAS_FAILURE" = true ]; then
    echo "One or more sync operations failed."
    exit 100
fi
echo "Done."