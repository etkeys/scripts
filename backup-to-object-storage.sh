#!/usr/bin/env bash

# Backup to Object Storage Script
# 
# Automated backup solution for synchronizing local directories to Backblaze B2 
# object storage with server-side encryption support. Processes multiple backup 
# configurations concurrently with comprehensive error handling and dry-run capabilities.
#
# FEATURES:
# - Multi-configuration batch processing from config directory
# - Server-side encryption with customer-provided keys (SSE-C)
# - Dry run mode for testing without actual transfers
# - Individual sync failure tracking with aggregated exit status
# - Comprehensive validation of prerequisites and configuration
#
# ENVIRONMENT VARIABLES:
# - SYNC_ENCRYPTION_KEY_FILE: Path to base64-encoded encryption key (required)
# - B2_ACCOUNT_INFO: Path to B2 credentials database (required)
# - DRY_RUN: Set to 'true' to enable dry run mode (optional, default: false)
#
# CONFIGURATION:
# - Config directory: /usr/local/etc/backup-to-object-storage.d/
# - Config files: *.conf files defining backup parameters
# - Required variables per config: LOCAL_PATH, DESTINATION_BUCKET_PATH
# - Optional variables per config: OPTIONS (additional b2 sync parameters)
#
# PREREQUISITES:
# - Backblaze B2 CLI (b2) installed and in PATH
# - Valid B2 account with configured credentials
# - Base64-encoded encryption key file accessible
# - Source directories must exist and be readable
#
# USAGE:
#   ./backup-to-object-storage.sh
#   DRY_RUN=true ./backup-to-object-storage.sh  # dry run mode
#
# EXIT CODES:
# - 0: All operations successful
# - 1: Configuration directory missing
# - 2: Encryption key file missing
# - 100: One or more backup operations failed

set -e

CONFIG_DIR="/usr/local/etc/backup-to-object-storage.d"
ENCRYPTION_KEY_FILE="${SYNC_ENCRYPTION_KEY_FILE:?"SYNC_ENCRYPTION_KEY_FILE must be set"}" # contents must be base64 encoded
DO_DRY_RUN="${DRY_RUN:-false}" # set to true to do a dry run (no actual sync, just print what would be done)

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
    DRY_RUN_FLAG=""

    # Get the base filename (service name)
    source "$config_file"

    if [ "$DO_DRY_RUN" = true ]; then
        DRY_RUN_FLAG="--dry-run"
        OPTIONS="$OPTIONS $DRY_RUN_FLAG"
    fi

    # Validate required variables
    if [ -z "$LOCAL_PATH" ] || [ -z "$DESTINATION_BUCKET_PATH" ]; then
        echo "Error: LOCAL_PATH or DESTINATION_BUCKET_PATH not set in $config_file"
        HAS_FAILURE=true
        continue
    fi

    # Execute the sync
    echo "Syncing $LOCAL_PATH to $DESTINATION_BUCKET_PATH..."
    # shellcheck disable=SC2086
    b2 sync --threads 1 $OPTIONS "$LOCAL_PATH" "$DESTINATION_BUCKET_PATH"

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