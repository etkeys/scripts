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

if [ -z "${DOCKER_COMPOSE_DIR}" ]; then
    echo "DOCKER_COMPOSE_DIR is not set. Using default: /usr/local/lib/open-webui/production"
    DOCKER_COMPOSE_DIR="/usr/local/lib/open-webui/production"
fi

cp "${DOCKER_COMPOSE_DIR}/compose.yml" "${DOCKER_COMPOSE_DIR}/.env" "${TEMP_DIR}/."
if [ $? -ne 0 ]; then
    echo "Error: Failed to copy compose.yml and .env from ${DOCKER_COMPOSE_DIR}"
    exit 2
else
    echo "compose.yml and .env copied successfully from ${DOCKER_COMPOSE_DIR}" 
fi