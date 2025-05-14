#!/usr/bin/env bash


# Check if a dataset was provided
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <zfs_dataset>"
    exit 1
fi

DATASET="$1"
SNAPSHOT_NAME=$(date +"%y%m%d")

# Function to check if a ZFS scrub is in progress
is_scrub_running() {
    zpool status | grep -q "scrub in progress"
}

# Wait for any ongoing scrub to complete
while is_scrub_running; do
    echo "ZFS scrub in progress. Waiting..."
    sleep 120  # Wait for 2 minute between checks
done

# Create the snapshot
zfs snapshot "${DATASET}@${SNAPSHOT_NAME}"

echo "Snapshot ${DATASET}@${SNAPSHOT_NAME} created successfully."