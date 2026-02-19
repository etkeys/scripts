#!/usr/bin/env bash

# ZFS Snapshot Management Script
#
# This script automates ZFS snapshot creation and retention management across
# multiple datasets based on configurable intervals (hourly, daily, weekly).
# It processes configuration files and automatically prunes old snapshots
# according to predefined retention policies.
#
# Features:
# - Interval-based snapshot creation (hourly, daily, weekly)
# - Automatic pruning with configurable retention policies:
#   * Hourly: Keep current day only (prune older than yesterday)
#   * Daily: Keep 7 days (prune older than 7 days)
#   * Weekly: Keep configurable weeks (default: 10 weeks)
# - Recursive snapshot support for dataset hierarchies
# - ZFS scrub detection and waiting (prevents conflicts during pool scrubs)
# - Configuration-driven dataset management
# - Comprehensive error handling and reporting
#
# Prerequisites:
# - ZFS utilities must be installed
# - Must be run with sudo/root privileges
# - Configuration files located in /usr/local/etc/create-zfs-snapshots.d/
# - Each configuration file (.conf) must define:
#   * DATASET: Full ZFS dataset path to snapshot
#   * INTERVALS: Comma-separated list of intervals for this dataset
#   * RECURSIVE: Optional boolean for recursive snapshots (default: false)
#
# Configuration Example:
#   DATASET="tank/data"
#   INTERVALS="hourly,daily,weekly"
#   RECURSIVE=true
#
# Usage:
#   ./create-zfs-snapshots.sh INTERVAL [OPTIONS]
#   
#   Examples:
#     ./create-zfs-snapshots.sh daily
#     ./create-zfs-snapshots.sh hourly --verbose
#
# Exit Codes:
# - 0: Success
# - 1: Invalid arguments or configuration directory missing
# - 2: Not running as root
# - 100: One or more snapshot operations failed
#
# Snapshot Naming Convention:
# - Hourly: auto-hourly-YYMMDDHH (e.g., auto-hourly-24052115)
# - Daily/Weekly: auto-[interval]-YYMMDD (e.g., auto-daily-240521)
# - Custom intervals: auto-[interval]-YYMMDD

CONFIG_DIR="${CONFIG_DIR:-/usr/local/etc/create-zfs-snapshots.d}"
SNAPSHOT_NAME=""
KEEP_WEEKLY=${KEEP_WEEKLY:-10}
INTERVAL=""

# Function to check if a ZFS scrub is in progress
is_scrub_running() {
    zpool status | grep -q "scrub in progress"
}

print_usage() {
    cat << EOF
Usage: $0 INTERVAL [OPTIONS]

OPTIONS:
    -v, --verbose                    Enable verbose output
    -h, --help                       Show this help message

ENVIRONMENT VARIABLES:
    CONFIG_DIR                       Directory containing snapshot configuration
                                     files (default: /usr/local/etc/create-zfs-snapshots.d)

EOF
}

prune_daily() {
    local dataset="$1"
    local recursive="$2"
    local result=0

    # don't keep daily snapshots older than 7 days
    local seven_days_ago=$(date -d "7 days ago" +"%y%m%d")
    local seven_days_ago_int=$((seven_days_ago))

    while read -r snapshot; do
        snapshot_name=$(cut -d'@' -f2 <<< "$snapshot")
        snapshot_time=${snapshot_name#auto-daily-}
        snapshot_time_int=$((snapshot_time))

        if [ "$snapshot_time_int" -le "$seven_days_ago_int" ]; then
            echo "Pruning old daily snapshot: $snapshot"
            if ! zfs destroy "$snapshot"; then
                echo "Error: Failed to prune $snapshot"
                result=1
            fi
        else
            break
        fi
    done < <(zfs list -Ho name -t snapshot "${dataset}" |
            grep -P "@auto-daily-\d{6}$" |
            sort)

    if [ "$recursive" = true ]; then
        while read -r child_dataset; do
            if ! prune_daily "$child_dataset" false; then
                result=1
            fi
        done < <(zfs list -Ho name |
                grep "^$dataset/" |
                sort)
    fi
    return $result
}

prune_hourly() {
    local dataset="$1"
    local recursive="$2"
    local result=0

    # don't keep hourly snapshots older than yesterday
    local yesterday=$(date -d "yesterday" +"%y%m%d%H")
    local yesterday_int=$((yesterday))

    # zfs list -Ho name -t snapshot "${dataset}" |
    # grep "@auto-hourly-" |
    # sort |
    # while read -r snapshot; do
    #     snapshot_name=$(cut -d'@' -f2 <<< "$snapshot")
    #     snapshot_time=${snapshot_name#auto-hourly-}
    #     snapshot_time_int=$((snapshot_time))

    #     if [ "$snapshot_time_int" -le "$yesterday_int" ]; then
    #         echo "Pruning old hourly snapshot: $snapshot"
    #         if ! zfs destroy "$snapshot"; then
    #             echo "Error: Failed to prune $snapshot"
    #             result=1
    #         fi
    #     else
    #         break
    #     fi
    # done
    while read -r snapshot; do
        snapshot_name=$(cut -d'@' -f2 <<< "$snapshot")
        snapshot_time=${snapshot_name#auto-hourly-}
        snapshot_time_int=$((snapshot_time))

        if [ "$snapshot_time_int" -le "$yesterday_int" ]; then
            echo "Pruning old hourly snapshot: $snapshot"
            if ! zfs destroy "$snapshot"; then
                echo "Error: Failed to prune $snapshot"
                result=1
            fi
        else
            break
        fi
    done < <(zfs list -Ho name -t snapshot "${dataset}" |
            grep -P "@auto-hourly-\d{8}$" |
            sort)

    if [ "$recursive" = true ]; then
        # zfs list -Ho name |
        # grep "^$dataset/" |
        # sort |
        # while read -r child_dataset; do
        #     if ! prune_hourly "$child_dataset" false; then
        #         result=1
        #     fi
        # done
        while read -r child_dataset; do
            if ! prune_hourly "$child_dataset" false; then
                result=1
            fi
        done < <(zfs list -Ho name |
                grep "^$dataset/" |
                sort)
    fi
    return $result
}

prune_weekly() {
    local dataset="$1"
    local recursive="$2"
    local result=0

    # don't keep weekly snapshots older than configured number of weeks
    local weeks_ago=$(date -d "$KEEP_WEEKLY weeks ago" +"%y%m%d")
    local weeks_ago_int=$((weeks_ago))

    while read -r snapshot; do
        snapshot_name=$(cut -d'@' -f2 <<< "$snapshot")
        snapshot_time=${snapshot_name#auto-weekly-}
        snapshot_time_int=$((snapshot_time))

        if [ "$snapshot_time_int" -le "$weeks_ago_int" ]; then
            echo "Pruning old weekly snapshot: $snapshot"
            if ! zfs destroy "$snapshot"; then
                echo "Error: Failed to prune $snapshot"
                result=1
            fi
        else
            break
        fi
    done < <(zfs list -Ho name -t snapshot "${dataset}" |
            grep -P "@(auto-weekly-\d{6}|\d+)" |
            sort)

    if [ "$recursive" = true ]; then
        while read -r child_dataset; do
            if ! prune_weekly "$child_dataset" false; then
                result=1
            fi
        done < <(zfs list -Ho name |
                grep "^$dataset/" |
                sort)
    fi
    return $result
}

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Please use sudo."
  exit 2
fi


while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            if [ -z "$INTERVAL" ]; then
                INTERVAL="$1"
                shift
            else
                echo "Unknown option: $1"
                print_usage
                exit 1
            fi
            ;;
    esac
done

if [ -z "$INTERVAL" ]; then
    echo "Error: INTERVAL argument is required."
    print_usage
    exit 1
fi

if [ ! -e "$CONFIG_DIR" ]; then
    echo "Error: Configuration directory $CONFIG_DIR does not exist"
    exit 1
fi

# Wait for any ongoing scrub to complete
while is_scrub_running; do
    echo "ZFS scrub in progress. Waiting..."
    sleep 120  # Wait for 2 minute between checks
done

SNAPSHOT_NAME="auto-$INTERVAL"
if [ "$INTERVAL" = "hourly" ]; then
    SNAPSHOT_NAME="$SNAPSHOT_NAME-$(date +"%y%m%d%H")"
else
    SNAPSHOT_NAME="$SNAPSHOT_NAME-$(date +"%y%m%d")"
fi

HAS_FAILURE=false
for config_file in "$CONFIG_DIR"/*.conf; do
    # Skip if not a file
    [ -f "$config_file" ] || continue

    DATASET=""
    RECURSIVE=false
    INTERVALS=""

    # Get the base filename (service name)
    source "$config_file"

    # Validate required variables
    if [ -z "$DATASET" ]; then
        echo "Error: DATASET not set in $config_file"
        HAS_FAILURE=true
        continue
    fi

    if ! zfs list -H -o name "$DATASET" &>/dev/null; then
        echo "Error: Dataset $DATASET does not exist"
        HAS_FAILURE=true
        continue
    fi

    if [ -z "$INTERVALS" ]; then
        echo "Error: INTERVALS not set in $config_file"
        HAS_FAILURE=true
        continue
    fi

    if [[ ! " $INTERVALS " =~ $INTERVAL ]]; then
        echo "Skipping $DATASET: INTERVAL $INTERVAL not in $INTERVALS"
        continue
    fi

    RECURSE_ARG=""
    if [ "$RECURSIVE" = true ]; then
        RECURSE_ARG="-r"
    fi

    # Take a snapshot of the dataset
    echo "Creating snapshot for dataset $DATASET..."
    zfs snapshot $RECURSE_ARG "${DATASET}@${SNAPSHOT_NAME}"

    if [ $? -ne 0 ]; then
        echo "Error: Failed to create snapshot for $DATASET"
        HAS_FAILURE=true
        continue
    fi

    echo "Snapshot ${DATASET}@${SNAPSHOT_NAME} created successfully."

    echo "Pruning old snapshots for $DATASET..."
    case "$INTERVAL" in
        hourly)
            if ! prune_hourly "${DATASET}" "${RECURSIVE}"; then
                HAS_FAILURE=true
            fi
            ;;
        daily)
            if ! prune_daily "${DATASET}" "${RECURSIVE}"; then
                HAS_FAILURE=true
            fi
            ;;
        weekly)
            if ! prune_weekly "${DATASET}" "${RECURSIVE}"; then
                HAS_FAILURE=true
            fi
            ;;
        *)
            echo "Snapshots created with custom interval '$INTERVAL': ${SNAPSHOT_NAME}"
            ;;
    esac
done

if [ "$HAS_FAILURE" = true ]; then
    echo "One or more snapshot operations failed."
    exit 100
fi

echo "Done."