#!/usr/bin/env bash

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

export APP_CONFIG TEMP_DIR BACKUP_DATETIME BACKUP_DIR

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

    run-parts \
        --verbose \
        --exit-on-error \
        --umask=027 \
        "${APP_RUN_DIR}"
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to run backup scripts for ${APP_NAME}."
        HAS_FAILURE=true
    else
        echo "Backup scripts executed successfully for ${APP_NAME}."

        chgrp -R adm "${BACKUP_DIR}"
        if [[ $? -ne 0 ]]; then
            echo "Error: Failed to create backup directory ${BACKUP_DIR}."
            HAS_FAILURE=true
        fi
    fi

    cleanup "${TEMP_DIR}"
done