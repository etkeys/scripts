#!/usr/bin/env bash

#
# Application Backup Orchestrator Script
# --------------------------------------
# This script automates backups for multiple applications using per-app configuration
# and backup scripts.
#
# Features:
# - Processes multiple app configurations from .conf files in a config directory
# - Creates and manages dedicated backup directories for each app
# - Cleans up old backup files before each run
# - Uses temporary directories for intermediary files
# - Executes numbered backup scripts for each app via run-parts
# - Reports success or failure for each app backup
#
# Usage:
#   sudo ./backup-apps.sh
#
# Configuration:
#   Place .conf files in /usr/local/etc/backup-apps-config.d/
#   Place backup scripts for each app in /usr/local/lib/backup-apps-scripts/<appname>/
#
# Exit codes:
#   0 - Success (all backups completed successfully)
#   2 - Must be run as root
#
# Environment variables set for backup scripts:
#   APP_CONFIG      - Path to the app's .conf file
#   TEMP_DIR        - Temporary directory for backup operations
#   BACKUP_DATETIME - Date string for backup naming
#   BACKUP_DIR      - Directory to store backups for the app

CONFIG_DIR="/usr/local/etc/backup-apps-config.d"
RUN_ROOT_DIR="/usr/local/lib/backup-apps-scripts"
BACKUP_DIR_ROOT="/var/local/backups"

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Please use sudo."
  exit 2
fi

cleanup() {
    local temp_dir="$1"
    echo "Cleaning up temporary files in ${temp_dir}..."
    rm -rf "${temp_dir}"
    echo "Temporary files cleaned up."
}

BACKUP_DATETIME=$(date +%y%m%d)
APP_CONFIG=""
TEMP_DIR=""
BACKUP_DIR=""

umask 027

HAS_FAILURE=false
for APP_CONFIG in "${CONFIG_DIR}"/*.conf; do
    if [[ ! -f "${APP_CONFIG}" ]]; then
        echo "No configuration files found in ${CONFIG_DIR}."
        HAS_FAILURE=true
        continue
    fi

    APP_NAME=$(basename -s ".conf" "${APP_CONFIG}")
    BACKUP_DIR="${BACKUP_DIR_ROOT}/${APP_NAME}"

    if [[ ! -d "${BACKUP_DIR}" ]]; then
        echo "Creating backup directory for ${APP_NAME} at ${BACKUP_DIR}..."
        mkdir -p "${BACKUP_DIR}"
        if [[ $? -ne 0 ]]; then
            echo "Error: Failed to create backup directory ${BACKUP_DIR}."
            HAS_FAILURE=true
            continue
        fi
        chgrp adm "${BACKUP_DIR}"
        chmod g+s "${BACKUP_DIR}"
    else
        echo "Deleting all files in ${BACKUP_DIR}"
        find "${BACKUP_DIR}" -type f -exec rm -f {} \;
    fi

    TEMP_DIR=$(mktemp -d)
    if [[ ! -d "${TEMP_DIR}" ]]; then
        echo "Error: Failed to create temporary directory."
        HAS_FAILURE=true
        continue
    fi

    APP_RUN_DIR="${RUN_ROOT_DIR}/${APP_NAME}"

    export APP_CONFIG TEMP_DIR BACKUP_DATETIME BACKUP_DIR

    run-parts \
        --verbose \
        --exit-on-error \
        --umask=027 \
        --regex='^[0-9]+' \
        "${APP_RUN_DIR}" 2>&1
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to run backup scripts for ${APP_NAME}."
        HAS_FAILURE=true
    else
        echo "Backup scripts executed successfully for ${APP_NAME}."
    fi

    cleanup "${TEMP_DIR}"
done
