#!/usr/bin/env bash

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Please use sudo."
  exit 1
fi

if [ -z "${APP_CONFIG}" ]; then
    echo "APP_CONFIG environment variable is not set. Please set it to the path of your APP_CONFIGuration file."
    exit 1
elif [ ! -f "${APP_CONFIG}" ]; then
    echo "APP_CONFIGuration file ${APP_CONFIG} does not exist."
    exit 1
fi

if [ -z "${TEMP_DIR}" ]; then
    echo "TEMP_DIR is not set. Please set it to a valid temporary directory."
    exit 1
elif [ ! -d "${TEMP_DIR}" ]; then
    echo "Temporary directory ${TEMP_DIR} does not exist."
    exit 1
fi

if [ -z "${BACKUP_DATETIME}" ]; then
    echo "BACKUP_DATETIME is not set. Please set it."
    exit 1
fi

if [ -z "${BACKUP_DIR}" ]; then
    echo "BACKUP_DIR is not set. Using default: /var/local/backups/caddy"
    BACKUP_DIR="/var/local/backups/caddy"
fi

CADDY_DIR=""
source "${APP_CONFIG}"

if [ -z "${CADDY_DIR}" ]; then
    echo "CADDY_DIR is not set in the APP_CONFIG. Please set it to the path of your Caddy directory."
    exit 1
elif [ ! -d "${CADDY_DIR}" ]; then
    echo "Caddy directory ${CADDY_DIR} does not exist."
    exit 1
fi

# "./" is used to ensure the current directory is included in the tarball
#   but not the actual top-level directory (so it doesn't apply incorrect permissions)
tar -czf "${BACKUP_DIR}/caddy.${BACKUP_DATETIME}.tar.gz" \
    --exclude='sites-enabled/*' \
    -C "${CADDY_DIR}" \
    ./
if [ $? -ne 0 ]; then
    echo "Error: Failed to create backup archive in ${BACKUP_DIR}"
    exit 2
else
    echo "Backup archive created successfully in ${BACKUP_DIR}/caddy.${BACKUP_DATETIME}.tar.gz"
fi