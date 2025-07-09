#!/usr/bin/env bash
#
# ZFS Snapshot Pruning Script
# ----------------------------
# This script automatically removes old ZFS snapshots that exceed a specified age.
#
# Features:
# - Waits for any running ZFS scrub to complete before pruning snapshots
# - Skips snapshots with a hyphen in their name (assumed to be manual/special snapshots)
# - Configurable retention period (default: 63 days)
# - Dry-run (on by default) mode to preview what would be deleted without making changes
#
# Usage:
#   ./prune-zfs-snapshots.sh
#
# Environment variables:
#   TIMESTAMP_OFFSET_DAYS - Number of days to keep snapshots (default: 63)
#   PRUNE_COMMIT_DELETE   - Set to 'true' to actually delete snapshots (default: false)
#
# Exit codes:
#   0 - Success (snapshots deleted or would be deleted in dry-run mode)
#   1 - Error (some snapshots could not be deleted)
#

TIMESTAMP_OFFSET="${TIMESTAMP_OFFSET_DAYS:-63}"  # Default to 63 days if not set
COMMIT_DELETE="${PRUNE_COMMIT_DELETE:-false}"  # Default to false if not set

# Function to check if a ZFS scrub is in progress
is_scrub_running() {
    zpool status | grep -q "scrub in progress"
}

# Wait for any ongoing scrub to complete
while is_scrub_running; do
    echo "ZFS scrub in progress. Waiting..."
    sleep 120  # Wait for 2 minutes between checks
done

TARGET_TIMESTAMP=$(date -d "$TIMESTAMP_OFFSET days ago" +%s)
HAS_FAILURE=false

zfs list -Hpt snapshot -s creation -o creation,name |
while read -r creation_timestamp name; do
    # Skip this snapshot if it contains '-' after '@'
    # This is to avoid deleting snapshots that were created manually
    # for a specific purpose or are not part of the automated process
    if [[ "$name" =~ @.+- ]]; then
        continue
    fi

    # Check if the snapshot is older than the designated time
    if [ "$creation_timestamp" -lt "$TARGET_TIMESTAMP" ]; then
        if [ "$COMMIT_DELETE" = true ]; then
            echo "Deleting snapshot: $name"
            zfs destroy "$name"
            if [ $? -ne 0 ]; then
                echo "Error: Failed to delete snapshot $name"
                HAS_FAILURE=true
            fi
        else
            # If COMMIT_DELETE is false, just print the snapshot name
            echo "Would delete snapshot: '$name' (not actually deleting due to COMMIT_DELETE=false)"
        fi
    fi
done

if [ "$HAS_FAILURE" = true ]; then
    echo "Some snapshots could not be deleted."
    exit 1
elif [ "$COMMIT_DELETE" = false ]; then
    echo "Old snapshots would be deleted, but COMMIT_DELETE is set to false."
    exit 0
else
    echo "Old snapshots deleted successfully."
    exit 0
fi