#!/usr/bin/env bash

# check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

VERBOSE=false

KEY_SOURCES=${KEY_SOURCES:?"Environment variable KEY_SOURCES is not set. It should contain a comma-separated list of key source IPs."}
DATASET=${DATASET:?"Environment variable DATASET is not set. It should contain the ZFS dataset to unlock."}
PASSPHRASE=""
export DECRYPT_KEY=""
export ENCRYPTED_PASSPHRASE=""

MQTT_CREDENTIALS_FILE="${MQTT_CREDENTIALS_FILE:?"Environment variable MQTT_CREDENTIALS_FILE is not set. It should contain the path to the MQTT credentials file."}"
MQTT_BROKER_IP=""
MQTT_BROKER_PORT=""
MQTT_USERNAME=""
MQTT_PASSWORD=""
MQTT_TOPIC_REQUEST=""
MQTT_TOPIC_RESPONSE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        # -h|--help)
        #     print_usage
        #     exit 0
        #     ;;
        *)
            write_log "Unknown option: $1"
            # print_usage
            exit 2
            ;;
    esac
done

if [ ! -f "$MQTT_CREDENTIALS_FILE" ]; then
    echo "MQTT credentials file not found: $MQTT_CREDENTIALS_FILE"
    exit 1
fi


ping_key_source() {
    local ip="$1"
    ping -c 4 -W 2 "$ip" &> /dev/null
    return $?
}

print_verbose() {
    if [ $VERBOSE = true ]; then
        echo "$1"
    fi
}

IFS=',' read -r -a key_source_ips <<< "$KEY_SOURCES"

for ip in "${key_source_ips[@]}"; do
    print_verbose "Pinging key source: $ip"
    if ! ping_key_source "$ip"; then
        echo "Key source $ip is not reachable."
        exit 1
    fi
done

# Get the mac address of each item in key_source_ips and concatenate them
for ip in "${key_source_ips[@]}"; do
    # Lookup MAX address in arp table
    mac_address=$(grep "^$ip\s" /proc/net/arp | awk '{print $4}')
    if [ -z "$mac_address" ]; then
        echo "Could not find MAC address for IP $ip"
        exit 1
    fi
    print_verbose "Found MAC address $mac_address for IP $ip"
    DECRYPT_KEY+="$mac_address"
done

MQTT_CREDENTIALS_FILE_CONTENTS=$(openssl enc -d -base64 -aes-256-cbc -pbkdf2 -nosalt -in "$MQTT_CREDENTIALS_FILE" -pass env:DECRYPT_KEY 2>/dev/null)

if ! echo "$MQTT_CREDENTIALS_FILE_CONTENTS" | grep -q "MQTT_BROKER_IP="; then
    echo "Failed to decrypt MQTT credentials file or invalid format."
    exit 1
fi

source <(echo "$MQTT_CREDENTIALS_FILE_CONTENTS")

# Validate required MQTT variables
if [ -z "$MQTT_BROKER_IP" ] || [ -z "$MQTT_BROKER_PORT" ] || [ -z "$MQTT_USERNAME" ] || [ -z "$MQTT_PASSWORD" ] \
    || [ -z "$MQTT_TOPIC_REQUEST" ] || [ -z "$MQTT_TOPIC_RESPONSE" ]; then
    echo "One or more required MQTT variables are missing in the credentials file."
    exit 1
fi

# get encrypted passphrase from MQTT broker
# first send request to broker
mosquitto_pub \
    --host "$MQTT_BROKER_IP" \
    --port "$MQTT_BROKER_PORT" \
    --username "$MQTT_USERNAME" \
    --pw "$MQTT_PASSWORD" \
    --topic "$MQTT_TOPIC_REQUEST" \
    --message "$DATASET" \
    --qos 1

# then subscribe to response topic to get the encrypted passphrase
ENCRYPTED_PASSPHRASE=$(mosquitto_sub \
    --host "$MQTT_BROKER_IP" \
    --port "$MQTT_BROKER_PORT" \
    --username "$MQTT_USERNAME" \
    --pw "$MQTT_PASSWORD" \
    --topic "$MQTT_TOPIC_RESPONSE" \
    -W 10 \
    -C 1)
if [ -z "$ENCRYPTED_PASSPHRASE" ]; then
    echo "Failed to retrieve encrypted passphrase from MQTT broker."
    exit 1
fi
echo "Retrieved encrypted passphrase from MQTT broker. (${ENCRYPTED_PASSPHRASE:0:10}...)"

## Note: to encrypt the passphrase for testing, use:
# export DECRYPT_KEY="your_decrypt_key_here"
#  echo "your_passphrase_here" | openssl enc -base64 -e -aes-256-cbc -pbkdf2 -nosalt -pass env:DECRYPT_KEY
# ^ put a leading space before echo to keep command out of history

# decrypt passphrase
PASSPHRASE="$(echo "$ENCRYPTED_PASSPHRASE" | openssl enc -base64 -d -aes-256-cbc -pbkdf2 -nosalt -pass env:DECRYPT_KEY 2>/dev/null)"
if [ -z "$PASSPHRASE" ]; then
    echo "Failed to decrypt passphrase."
    exit 1
fi

echo "Attempting to unlock ZFS dataset: $DATASET"
if zfs get -H -o value keystatus "$DATASET" | grep -q "unavailable"; then
    echo "ZFS dataset is currently locked."
    if printf '%s' "$PASSPHRASE" | zfs load-key "$DATASET" -r; then
        echo "Successfully unlocked ZFS dataset."
    else
        echo "Failed to unlock ZFS dataset."
        exit 1
    fi
else
    echo "ZFS dataset is already unlocked."
fi

# mount dataset and all its children.
# Have to do this manually because there is
# no way to mount all children with a single command
# There is a feature request that has been merged but
# not in a version that is widely available yet:
# https://github.com/openzfs/zfs/issues/2901

zfs list -Ho name |
grep "^$DATASET" |
sort |
while read -r dataset_to_mount; do
    echo "Mounting ZFS dataset: $dataset_to_mount"
    if zfs get -H -o value mounted "$dataset_to_mount" | grep -q "no"; then
        if zfs mount "$dataset_to_mount"; then
            echo "Successfully mounted ZFS dataset: $dataset_to_mount"
        else
            echo "Failed to mount ZFS dataset: $dataset_to_mount"
            exit 1
        fi
    else
        echo "ZFS dataset is already mounted."
    fi
done

exit 0