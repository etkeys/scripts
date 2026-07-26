#!/usr/bin/env bash
#
# notify-zfs-unlock-failure.sh
# Publishes an MQTT alert when a ZFS dataset unlock fails.
# Designed to be called by systemd OnFailure= handler.
#
# Usage: notify-zfs-unlock-failure.sh <dataset>
#   e.g. notify-zfs-unlock-failure.sh vmbackupspool/data

set -euo pipefail

DATASET="${1:-}"
if [ -z "$DATASET" ]; then
    echo "Error: DATASET argument required" >&2
    exit 1
fi

# ── Configuration ──────────────────────────────────────────────
KEY_SOURCES="${KEY_SOURCES:-}"
MQTT_CREDENTIALS_FILE="${MQTT_CREDENTIALS_FILE:-}"
MQTT_BROKER_IP="${MQTT_BROKER_IP:-}"
MQTT_BROKER_PORT="${MQTT_BROKER_PORT:-1883}"
MQTT_TOPIC="${MQTT_TOPIC:-}"
DOCKER_CONTAINER="${MOSQUITTO_CONTAINER:-}"   # set in environment if needed


if [ -z "$KEY_SOURCES" ]; then
    echo "Error: KEY_SOURCES environment variable is not set"
    exit 1
fi
if [ -z "$MQTT_CREDENTIALS_FILE" ]; then
    echo "Error: MQTT_CREDENTIALS_FILE environment variable is not set"
    exit 1
fi
if [ -z "$MQTT_BROKER_IP" ]; then
    echo "Error: MQTT_BROKER_IP environment variable is not set"
    exit 1
fi
if [ -z "$MQTT_BROKER_PORT" ]; then
    echo "Error: MQTT_BROKER_PORT environment variable is not set"
    exit 1
fi
if [ -z "$MQTT_TOPIC" ]; then
    echo "Error: MQTT_TOPIC environment variable is not set"
    exit 1
fi

DECRYPT_KEY=""

IFS=',' read -r -a key_source_ips <<< "$KEY_SOURCES"

for ip in "${key_source_ips[@]}"; do
    if ! grep -q "^$ip\s" /proc/net/arp && ! ping -c 4 -W 2 "$ip" &>/dev/null; then
        echo "Key source $ip is not reachable." >&2
        exit 1
    fi
    mac_address=$(grep "^$ip\s" /proc/net/arp | awk '{print $4}')
    if [ -z "$mac_address" ]; then
        echo "Could not find MAC address for IP $ip" >&2
        exit 1
    fi
    DECRYPT_KEY+="$mac_address"
done

if [ ! -f "$MQTT_CREDENTIALS_FILE" ]; then
    echo "MQTT credentials file not found: $MQTT_CREDENTIALS_FILE" >&2
    exit 1
fi

MQTT_CREDS=$(openssl enc -d -base64 -aes-256-cbc -pbkdf2 -nosalt \
    -in "$MQTT_CREDENTIALS_FILE" -pass env:DECRYPT_KEY 2>/dev/null)

if ! echo "$MQTT_CREDS" | grep -q "MQTT_USERNAME="; then
    echo "Failed to decrypt MQTT credentials." >&2
    exit 1
fi

source <(echo "$MQTT_CREDS")

# ── Publish ─────────────────────────────────────────────────────
CMD_PREFIX=()
if [ -n "$DOCKER_CONTAINER" ]; then
    CMD_PREFIX=(docker exec -i "$DOCKER_CONTAINER")
fi

"${CMD_PREFIX[@]}" mosquitto_pub \
    --host "$MQTT_BROKER_IP" \
    --port "$MQTT_BROKER_PORT" \
    --username "$MQTT_USERNAME" \
    --pw "$MQTT_PASSWORD" \
    --topic "$MQTT_TOPIC" \
    --message "$DATASET" \
    --qos 1

echo "Alert published to $MQTT_TOPIC for dataset $DATASET"
exit 0