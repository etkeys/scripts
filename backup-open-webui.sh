#!/usr/bin/env bash
#
# Open WebUI Backup Script
# -----------------------
# This script creates a backup of an Open WebUI installation running in Docker containers.
#
# Features:
# - Backs up the LiteLLM PostgreSQL database
# - Backs up the Open WebUI SQLite database
# - Saves Docker Compose configuration files
# - Creates a timestamped tarball containing all backup components
# - Uses temporary directory for intermediary files
# - Cleans up after itself
#
# Usage:
#   sudo ./backup-open-webui.sh
#
# Environment variables:
#   BACKUP_DIR                  - Directory to store backups (default: /var/local/backups/open-webui)
#   DOCKER_LITELLMDB_CONTAINER  - Name of LiteLLM database container (default: litellm-db)
#   DOCKER_OPENWEBUI_CONTAINER  - Name of Open WebUI container (default: open-webui)
#   DOCKER_COMPOSE_DIR          - Directory with Docker Compose files (default: /usr/local/lib/open-webui/production)
#
# Exit codes:
#   0 - Success (backup created successfully)
#   1 - General error
#   2 - Operation failed (specific error details provided in output)
#

BACKUP_DIR="${BACKUP_DIR:-/var/local/backups/open-webui}"
TODAY_DATE=$(date +%y%m%d)
TEMP_DIR=$(mktemp -d)

DOCKER_LITELLMDB_CONTAINER="${DOCKER_LITELLMDB_CONTAINER:-litellm-db}"
DOCKER_OPENWEBUI_CONTAINER="${DOCKER_OPENWEBUI_CONTAINER:-open-webui}"
DOCKER_COMPOSE_DIR="${DOCKER_COMPOSE_DIR:-/usr/local/lib/open-webui/production}"

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Please use sudo."
  exit 2
fi

cleanup() {
    echo "Cleaning up temporary files..."
    cd /tmp || exit 1
    rm -rf "${TEMP_DIR}"
}

if [ ! -d "${BACKUP_DIR}" ]; then
    echo "Backup directory ${BACKUP_DIR} does not exist. Creating it."
    mkdir -p "${BACKUP_DIR}"
else
    echo "Deleting all files in ${BACKUP_DIR}"
    find "${BACKUP_DIR}" -type f -exec rm -f {} \;
fi

cd "${TEMP_DIR}" || exit 1
echo "Temporary directory is ${TEMP_DIR}"

docker exec -t "${DOCKER_LITELLMDB_CONTAINER}" \
    pg_dump -c -U postgres -d litellm |
    gzip > "litellm-db.sql.gz"
if [ $? -ne 0 ]; then
    echo "Error: Failed to dump the database from container ${DOCKER_LITELLMDB_CONTAINER}"
    cleanup
    exit 2
else
    echo "Database dump created successfully in ${TEMP_DIR}/litellm-db.sql.gz"
fi

docker cp "${DOCKER_OPENWEBUI_CONTAINER}:/app/backend/data/webui.db" webui.db
if [ $? -ne 0 ]; then
    echo "Error: Failed to copy webui.db from container ${DOCKER_OPENWEBUI_CONTAINER}"
    cleanup
    exit 2
else
    echo "webui.db copied successfully from container ${DOCKER_OPENWEBUI_CONTAINER}"
fi

cp "${DOCKER_COMPOSE_DIR}/compose.yml" "${DOCKER_COMPOSE_DIR}/.env" .
if [ $? -ne 0 ]; then
    echo "Error: Failed to copy compose.yml and .env from ${DOCKER_COMPOSE_DIR}"
    cleanup
    exit 2
else
    echo "compose.yml and .env copied successfully from ${DOCKER_COMPOSE_DIR}" 
fi

# "./" is used to ensure the current directory is included in the tarball
#   but not the actual top-level directory (so it doesn't apply incorrect permissions)
tar -czf "${BACKUP_DIR}/open-webui.${TODAY_DATE}.tar.gz" ./
if [ $? -ne 0 ]; then
    echo "Error: Failed to create backup archive in ${BACKUP_DIR}"
    cleanup
    exit 2
fi

echo "Backup created successfully at ${BACKUP_DIR}/open-webui.${TODAY_DATE}.tar.gz"
cleanup
exit 0
