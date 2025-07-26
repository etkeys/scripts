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

source "${APP_CONFIG}"

if [ -z "${DOCKER_LITELLMDB_CONTAINER}" ]; then
    echo "DOCKER_LITELLMDB_CONTAINER is not set. Using default: litellm-db"
    DOCKER_LITELLMDB_CONTAINER="litellm-db"
fi

docker exec -t "${DOCKER_LITELLMDB_CONTAINER}" \
    pg_dump -c -U postgres -d litellm |
    gzip > "${TEMP_DIR}/litellm-db.sql.gz"
if [ $? -ne 0 ]; then
    echo "Error: Failed to dump the database from container ${DOCKER_LITELLMDB_CONTAINER}"
    exit 2
else
    echo "Database dump created successfully in ${TEMP_DIR}/litellm-db.sql.gz"
fi