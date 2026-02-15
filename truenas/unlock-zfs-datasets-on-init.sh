#!/usr/bin/bash

set -o pipefail

# check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

DATASETS_ARRAY=()
KEY_SOURCES=""
LOG_FILE="/tmp/unlock-zfs-datasets-on-init.$(date +%Y%m%d_%H%M%S).log"
MOSQUITTO_CONTAINER=""
MQTT_CREDENTIALS_FILE=""
UNLOCK_SCRIPT=""
VERBOSE=false

wait_for_container() {
    local CONTAINER_NAME="$1"
    local MAX_WAIT="${2:-60}"  # Default 60 seconds
    local SLEEP_INTERVAL="${3:-2}"  # Default 2 seconds
    local elapsed=0

    if [ -z "$CONTAINER_NAME" ]; then
        echo "Error: Container name is required" | tee -a "$LOG_FILE"
        return 1
    fi

    echo "Checking if container '$CONTAINER_NAME' is running..." | tee -a "$LOG_FILE"

    while [ $elapsed -lt $MAX_WAIT ]; do
        # Check if container is running
        if docker ps --filter "name=$CONTAINER_NAME" --filter "status=running" --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
            echo "Container '$CONTAINER_NAME' is running!" | tee -a "$LOG_FILE"
            return 0
        fi
        
        echo "Container not running yet. Waiting... ($elapsed seconds elapsed)" | tee -a "$LOG_FILE"
        sleep $SLEEP_INTERVAL
        elapsed=$((elapsed + SLEEP_INTERVAL))
    done

    echo "Container '$CONTAINER_NAME' did not start within $MAX_WAIT seconds. Giving up." | tee -a "$LOG_FILE"
    return 1
}

touch "$LOG_FILE"

# Validate that the unlock script exists and is executable
if [ ! -x "$UNLOCK_SCRIPT" ]; then
    echo "Error: Unlock script '$UNLOCK_SCRIPT' does not exist or is not executable" | tee -a "$LOG_FILE"
    exit 1
fi

# Validate that the MQTT credentials file exists
if [ ! -f "$MQTT_CREDENTIALS_FILE" ]; then
    echo "Error: MQTT credentials file '$MQTT_CREDENTIALS_FILE' does not exist" | tee -a "$LOG_FILE"
    exit 1
fi

echo "Waiting for Mosquitto container to be ready..." | tee -a "$LOG_FILE"
if ! wait_for_container "$MOSQUITTO_CONTAINER" 120 2; then
    echo "Error: Mosquitto container '$MOSQUITTO_CONTAINER' is not ready" | tee -a "$LOG_FILE"
    exit 1
fi

for DATASET in "${DATASETS_ARRAY[@]}"; do
    VERBOSE_OPTION=""
    if [ -z "$DATASET" ]; then
        echo "Error: Empty dataset name in list" | tee -a "$LOG_FILE"
        exit 1
    fi
    if [ "$VERBOSE" = true ]; then
        echo "Unlocking dataset '$DATASET' using script '$UNLOCK_SCRIPT'" | tee -a "$LOG_FILE"
        VERBOSE_OPTION="--verbose"
    fi
    if "$UNLOCK_SCRIPT" \
        --dataset "$DATASET" \
        --key-sources "$KEY_SOURCES" \
        --mqtt-credentials "$MQTT_CREDENTIALS_FILE" \
        --mosquitto-container "$MOSQUITTO_CONTAINER" \
        $VERBOSE_OPTION | tee -a "$LOG_FILE"; then
        echo "Successfully unlocked dataset '$DATASET'" | tee -a "$LOG_FILE"
    else
        echo "Error: Failed to unlock dataset '$DATASET'" | tee -a "$LOG_FILE"
        exit 1
    fi
done