#!/usr/bin/env bash
#
# backup-nas-data.sh - ZFS snapshot backup utility
#
# This script backs up ZFS snapshots from a NAS to a local directory structure.
# It works by:
# 1. SSH'ing to a remote host (media002) to find the latest ZFS snapshot
# 2. Creating a local backup directory structure under ~/nas_backup
# 3. Processing each configuration file in the config.d directory
# 4. For each config file, retrieving the dataset's mount point and backing up 
#    the snapshot using rsync
# 5. Logging all operations to timestamped log files
#
# Configuration files must define at least:
# - DATASET: the ZFS dataset path to back up
#
# Options:
#   -v, --verbose    Enable verbose output
#   -h, --help       Display help message and exit
#
# Exit codes:
#   1 - Bad cli arguments or invocation
#   2 - Bad configuration directory
#   3 - Unknown to determin snapshot
#   4 - Backup job failed
#
set -eu

readonly ENO_BAD_CLI=1
readonly ENO_BAD_CONFIG_DIR=2
readonly ENO_UNKNOWN_SNAPSHOT=3
readonly ENO_FAILED_JOB=4

readonly BACKUP_ROOT_DIR="${HOME}/nas_backup"
readonly CONFIG_DIR="${BACKUP_ROOT_DIR}/config.d"
readonly SSH_HOST="media002"

SNAPSHOT_NAME=""
SNAPSHOT_BACKUP_DIR=""
VERBOSE=false
LOG_DIR=""

# Function to print usage information
print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -v, --verbose    Enable verbose output"
    echo "  -h, --help       Display this help message and exit"
}

# Function to print verbose messages
print_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo "$@"
    fi
}

process_config() {
    local config_file="$1"
    # Skip if not a file
    if [ ! -f "${config_file}" ]; then
        echo "Skipping non-file: ${config_file}"
        return 1
    fi
    echo "Processing configuration file ${config_file}"

    # Use a full, absolute path or validate the config file location
    # shellcheck disable=SC1090
    source "${config_file}"
    if [ -z "${DATASET}" ]; then
        echo "Error: DATASET not set in ${config_file}"
        return 1
    fi
    print_verbose "Dataset: ${DATASET}"

    local dataset_mount_point
    dataset_mount_point="$(ssh ${SSH_HOST} zfs get -Ho value mountpoint "${DATASET}")"
    print_verbose "Mount point: ${dataset_mount_point}"
    if [ -z "${dataset_mount_point}" ]; then
        echo "Error: Could not determine mount point for dataset ${DATASET}"
        return 1
    fi

    local source_dir
    source_dir="${dataset_mount_point}/.zfs/snapshot/${SNAPSHOT_NAME}"
    print_verbose "Source directory: ${source_dir}"
    if ! ssh ${SSH_HOST} "[ -d '${source_dir}' ]"; then
        echo "Error: Source directory ${source_dir} does not exist for dataset ${DATASET}"
        return 1
    fi

    local destination_name
    local destination_dir
    destination_name="${DATASET##*/}"
    destination_name="${destination_name%.*}"
    destination_dir="${SNAPSHOT_BACKUP_DIR}/${destination_name}"
    print_verbose "Destination directory: ${destination_dir}"
    if [ -d "${destination_dir}" ]; then
        echo "Error: Destination directory ${destination_dir} already exists for dataset ${DATASET} in ${config_file}"
        return 1
    fi

    local log_file="${LOG_DIR}/${destination_name}.log"
    print_verbose "Log file: ${log_file}"
    
    mkdir -p "${destination_dir}"
    rsync -av \
        --progress \
        "${SSH_HOST}:${source_dir}/." \
        "${destination_dir}" > "${log_file}" 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: rsync failed for ${config_file} - see log at ${log_file}"
        return 1
    else
        echo "Successfully processed ${config_file} - log at ${log_file}"
        return 0
    fi
}

process_all_configs() {
    local config_file
    local has_error=false
    for config_file in "${CONFIG_DIR}"/*.conf; do

        SECONDS=0

        process_config "${config_file}" || has_error=true

        local duration=$SECONDS
        # Print the duration in a human-readable format (00h 00m 00s)
        printf "Elapsed time: %02dh %02dm %02ds\n" \
            $((duration / 3600)) \
            $((duration % 3600 / 60)) \
            $((duration % 60))
    done

    if [ "${has_error}" = true ]; then
        echo "One or more configuration files had errors."
        return 1
    else
        echo "All configuration files processed successfully."
        return 0
    fi
}

# Simple command line argument parsing
for arg in "$@"; do
    case "$arg" in
        -v|--verbose)
            VERBOSE=true
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $arg" >&2
            print_usage >&2
            exit $ENO_BAD_CLI
            ;;
    esac
done

if [ ! -e "${CONFIG_DIR}" ]; then
    echo "Error: Configuration directory ${CONFIG_DIR} does not exist"
    exit $ENO_BAD_CONFIG_DIR
fi

# Create log directory
LOG_DIR="/tmp/backup-nas-data-logs-$(date +%Y%m%d-%H%M%S)"
mkdir -p "${LOG_DIR}"
print_verbose "Log directory: ${LOG_DIR}"

SNAPSHOT_NAME="$(
ssh $SSH_HOST zfs list -t snapshot -o name |
    tail -n+2 |
    cut -d '@' -f 2 |
    sort |
    uniq |
    tail -n 1)"
if [ -z "${SNAPSHOT_NAME}" ]; then
    echo "Error: Could not determine snapshot name."
    exit $ENO_UNKNOWN_SNAPSHOT
fi

print_verbose "Using snapshot: ${SNAPSHOT_NAME}"

SNAPSHOT_BACKUP_DIR="${BACKUP_ROOT_DIR}/${SNAPSHOT_NAME}"
print_verbose "Snapshot backup directory: ${SNAPSHOT_BACKUP_DIR}"
if [ ! -d "${SNAPSHOT_BACKUP_DIR}" ]; then
    print_verbose "Creating backup directory: ${SNAPSHOT_BACKUP_DIR}"
    mkdir -p "${SNAPSHOT_BACKUP_DIR}"
fi

if process_all_configs ; then
    echo "Backup completed successfully."
    echo "Log files are available in: ${LOG_DIR}"
else
    echo "Backup encountered errors."
    echo "Log files are available in: ${LOG_DIR}"
    exit $ENO_FAILED_JOB
fi
