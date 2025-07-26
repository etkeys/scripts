#!/usr/bin/env bash

CONFIG_DIR="/usr/local/etc/backup-apps-config.d"
RUN_ROOT_DIR="/usr/local/lib/backup-apps"

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

umask 027

HAS_FAILURE=false
for config_file in "${CONFIG_DIR}"/*.conf; do
    if [[ -f "${config_file}" ]]; then
        source "${config_file}"
    else
        echo "Warning: No configuration files found in ${CONFIG_DIR}."
        HAS_FAILURE=true
    fi

    # if creating app directory, set group ownership to adm
done