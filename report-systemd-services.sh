#!/usr/bin/env bash

set -e
set -u


# Use SYSTEMD_SERVICES_DIR environment variable or default path
SERVICES_DIR="${SYSTEMD_SERVICES_DIR:-/usr/local/etc/report-systemd-services.d}"

# Check if the directory/file exists
if [ ! -e "$SERVICES_DIR" ]; then
    echo "Error: Services directory/file $SERVICES_DIR does not exist"
    exit 1
fi

# If it's a directory, process files in the directory
if [ -d "$SERVICES_DIR" ]; then
    for service_file in "$SERVICES_DIR"/*; do
        # Skip if not a file
        [ -f "$service_file" ] || continue

        # Get the base filename (service name)
        service_name=$(basename "$service_file")

        # Check service status
        if systemctl is-failed "$service_name" > /dev/null 2>&1; then
            # is-failed returns 0 for failed services
            echo "$service_name: failed"
        else
            # is-failed returns non-zero for non-failed services
            echo "$service_name: ok"
        fi
    done
else
    echo "Error: $SERVICES_DIR is not a directory."
    exit 1
fi