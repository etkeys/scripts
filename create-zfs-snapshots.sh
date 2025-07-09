#!/usr/bin/env bash

# ZFS Snapshot Creation Script
#
# This script automates the creation of ZFS snapshots across multiple datasets
# by processing configuration files from a central directory.
#
# Features:
# - Supports multiple dataset snapshot configurations
# - Checks for and waits during active ZFS pool scrubs
# - Validates dataset existence before snapshot creation
# - Provides error handling and reporting
#
# Prerequisites:
# - ZFS utilities must be installed
# - Must be run with sudo/root privileges
# - Configuration files located in /usr/local/etc/create-zfs-snapshots.d/
# - Each configuration file must define:
#   * DATASET: Full ZFS dataset path to snapshot
#
# Usage:
#   ./create-zfs-snapshot.sh
#
# Exit Codes:
# - 1: Invalid arguments or configuration directory missing
# - 2: Not running as root
# - 100: One or more snapshot operations failed
#
# Snapshot Naming Convention:
# - Snapshots are named using a date format YYMMDD (e.g., 240521)

CONFIG_DIR="/usr/local/etc/create-zfs-snapshots.d"
SNAPSHOT_NAME=$(date +"%y%m%d")

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Please use sudo."
  exit 2
fi

if [ ! -e "$CONFIG_DIR" ]; then
    echo "Error: Configuration directory $CONFIG_DIR does not exist"
    exit 1
fi

# Function to check if a ZFS scrub is in progress
is_scrub_running() {
    zpool status | grep -q "scrub in progress"
}

# Wait for any ongoing scrub to complete
while is_scrub_running; do
    echo "ZFS scrub in progress. Waiting..."
    sleep 120  # Wait for 2 minute between checks
done

HAS_FAILURE=false
for config_file in "$CONFIG_DIR"/*.conf; do
    # Skip if not a file
    [ -f "$config_file" ] || continue

    DATASET=""
    RECURSIVE=false

    # Get the base filename (service name)
    source "$config_file"

    # Validate required variables
    if [ -z "$DATASET" ]; then
        echo "Error: DATASET not set in $config_file"
        HAS_FAILURE=true
        continue
    fi

    # Check if the dataset exists
    if ! zfs list -H -o name "$DATASET" &>/dev/null; then
        echo "Error: Dataset $DATASET does not exist"
        HAS_FAILURE=true
        continue
    fi

    RECURSE_ARG=""
    if [ "$RECURSIVE" = true ]; then
        RECURSE_ARG="-r"
    fi

    # Take a snapshot of the dataset
    echo "Creating snapshot for dataset $DATASET..."
    zfs snapshot $RECURSE_ARG "${DATASET}@${SNAPSHOT_NAME}"

    if [ $? -ne 0 ]; then
        echo "Error: Failed to create snapshot for $DATASET"
        HAS_FAILURE=true
        continue
    fi

    echo "Snapshot ${DATASET}@${SNAPSHOT_NAME} created successfully."
done

if [ "$HAS_FAILURE" = true ]; then
    echo "One or more snapshot operations failed."
    exit 100
fi
echo "Done."