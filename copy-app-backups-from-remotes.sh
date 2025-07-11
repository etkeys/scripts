#!/usr/bin/env bash
#
# Remote Backup Copy Script
# ------------------------
# This script copies application backups from remote servers to local directories
# based on configuration files in a specified directory.
#
# Features:
# - Processes multiple backup configurations from separate config files
# - Securely copies files using SSH with identity and known hosts files
# - Creates destination directories if they don't exist
# - Maintains a rolling backup by removing oldest files (keeps 10 most recent)
# - Reports success/failure for each configuration
#
# Usage:
#   ./copy-app-backups-from-remotes.sh
#
# Configuration:
#   Place .conf files in /usr/local/etc/copy-app-backup-from-remote.d/
#   Each .conf file should define these variables:
#     REMOTE_HOST         - Hostname of the remote server
#     REMOTE_DIR          - Directory on remote server containing backups
#     DESTINATION_DIR     - Local directory to store copied backups
#     SSH_IDENTITY_FILE   - Path to SSH private key file
#     SSH_KNOWN_HOSTS_FILE - Path to SSH known hosts file
#     SSH_USER            - Username for SSH connection
#
# Exit codes:
#   0   - Success (all configurations processed successfully)
#   1   - Configuration directory not found
#   100 - One or more errors occurred during processing
#

CONFIG_DIR="/usr/local/etc/copy-app-backup-from-remote.d"

if [ ! -d "$CONFIG_DIR" ]; then
    echo "Error: Configuration directory $CONFIG_DIR does not exist"
    exit 1
fi

HAS_FAILURE=false
for config_file in "$CONFIG_DIR"/*.conf; do
    # Skip if not a file
    [ -f "$config_file" ] || continue

    REMOTE_HOST=""
    REMOTE_DIR=""
    DESTINATION_DIR=""
    SSH_IDENTITY_FILE=""
    SSH_KNOWN_HOSTS_FILE=""
    SSH_USER=""

    source "$config_file"

    # Validate required variables
    if [ -z "$REMOTE_HOST" ]; then
        echo "Error: REMOTE_HOST not set in $config_file"
        HAS_FAILURE=true
        continue
    fi
    if [ -z "$REMOTE_DIR" ]; then
        echo "Error: REMOTE_DIR not set in $config_file"
        HAS_FAILURE=true
        continue
    fi
    if [ -z "$DESTINATION_DIR" ]; then
        echo "Error: DESTINATION_DIR not set in $config_file"
        HAS_FAILURE=true
        continue
    fi
    if [ -z "$SSH_IDENTITY_FILE" ]; then
        echo "Error: IDENTITY_FILE not set in $config_file"
        HAS_FAILURE=true
        continue
    fi
    if [ -z "$SSH_KNOWN_HOSTS_FILE" ]; then
        echo "Error: KNOWN_HOSTS_FILE not set in $config_file"
        HAS_FAILURE=true
        continue
    fi
    if [ -z "$SSH_USER" ]; then
        echo "Error: SSH_USER not set in $config_file"
        HAS_FAILURE=true
        continue
    fi

    if [ ! -d "$DESTINATION_DIR" ]; then
        echo "Creating destination directory: $DESTINATION_DIR"
        mkdir -p "$DESTINATION_DIR"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to create destination directory $DESTINATION_DIR"
            HAS_FAILURE=true
            continue
        fi
    fi

    rsync \
        --itemize-changes \
        --times \
        --rsh="ssh -i $SSH_IDENTITY_FILE -o UserKnownHostsFile=$SSH_KNOWN_HOSTS_FILE" \
        $SSH_USER@$REMOTE_HOST:"$REMOTE_DIR"/* \
        "$DESTINATION_DIR"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to copy files from $REMOTE_HOST:$REMOTE_DIR to $DESTINATION_DIR"
        HAS_FAILURE=true
    else
        echo "Successfully copied files from $REMOTE_HOST:$REMOTE_DIR to $DESTINATION_DIR"
    fi

    COUNT_FILES=$(ls -1 "$DESTINATION_DIR" | wc -l)
    while [ $COUNT_FILES -gt 10 ]; do
        OLDEST_FILE=$(ls -1 "$DESTINATION_DIR" | head -1)
        echo "Removing oldest backup file: $OLDEST_FILE"
        rm -f "$DESTINATION_DIR/$OLDEST_FILE"
        COUNT_FILES=$(ls -1 "$DESTINATION_DIR" | wc -l)
    done

    echo "Done processing $config_file."
done

if $HAS_FAILURE; then
    echo "Some errors occurred during processing."
    exit 100
fi
echo "All configurations processed successfully."
echo "Done."