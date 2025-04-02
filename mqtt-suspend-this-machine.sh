#!/usr/bin/env bash

MQTT_HOST="${HA_MQTT_HOST}"
MQTT_PASS="${HA_MQTT_PASSWORD:?Missing HA_MQTT_PASSWORD value}"
MQTT_USER="${HA_MQTT_USER:?Missing HA_MQTT_USER value}"

MQTT_TOPIC=""

compare_date_from_message() {
    MSG_DATE_PART=$(get_date_part_from_message "$1")

    if [[ "$MSG_DATE_PART" == "" ]]; then
        echo "Failed to extract date part from message: $1."
        exit 6
    fi

    DATE_NOW=$(date +%s)
    MSG_DATE=$(date -d "$MSG_DATE_PART" +%s)

    if [[ $DATE_NOW -le $MSG_DATE ]]; then
        echo "Date in message is in the future."
        return 1
    else
        return 0
    fi
}

get_date_part_from_message() {
    echo "$1" | grep -o " after .*" | cut -d " " -f 3
}

get_mqtt_message() {
    mosquitto_sub \
        --host "$MQTT_HOST" \
        --topic "$MQTT_TOPIC" \
        --username "$MQTT_USER" \
        --pw "$MQTT_PASS" \
        -C 1 \
        -W 10 
}

handle_suspend() {
    IS_DELAY="$1"
    if [ "$IS_DELAY" -ne 0 ]; then
        AFTER_DATE="$(date -d "+10 minute" --iso-8601=minutes)"
        publish_mqtt_message "suspend after $AFTER_DATE"
    else
        write_log "Suspending now."
        sudo systemctl suspend
    fi
}

print_usage() {
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -H, --host HOST      MQTT host to connect to"
    echo ""
    echo "  -t, --topic TOPIC  MQTT topic to subscribe to"
}

publish_mqtt_message() {
    write_log "Publishing message: $1"
    mosquitto_pub \
        --host "$MQTT_HOST" \
        --topic "$MQTT_TOPIC" \
        --username "$MQTT_USER" \
        --pw "$MQTT_PASS" \
        --message "$1" \
        --qos 0 \
        --retain
}

when_suspend_after() {
    compare_date_from_message "$1"
    COMPARE=$?
    if [ $COMPARE -eq 1 ]; then
        exit 0
    fi

    write_log "Suspend delay time elapsed."
    handle_suspend 0
}

when_suspend_enabled() {
    write_log "Suspend enabled. Setting delay."
    handle_suspend 1
}

write_log() {
    echo "$(date +%Y-%m-%dT%H:%M:%S) $1"
}

if ! command -v mosquitto_sub >/dev/null 2>&1 ; then
    write_log "mosquitto_sub not found. Please install mosquitto-clients."
    exit 1
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        -H|--host)
            MQTT_HOST="$2"
            shift
            shift
            ;;
        -t|--topic)
            MQTT_TOPIC="$2"
            shift
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            write_log "Unknown option: $1"
            print_usage
            exit 2
            ;;
    esac
done

if [[ "$MQTT_HOST" == "" ]]; then
    write_log "Missing MQTT host."
    print_usage
    exit 2
fi

if [[ "$MQTT_TOPIC" == "" ]]; then
    write_log "Missing MQTT topic."
    print_usage
    exit 2
fi

MSG="$(get_mqtt_message)"

write_log "Received message: $MSG"

if [ $? -ne 0 ]; then
    write_log "Failed to subscribe to MQTT topic '$MQTT_TOPIC' on host '$MQTT_HOST'."
    exit 3
fi

if [[ "$MSG" == "" ]]; then
    write_log "No message received."
    exit 4
fi

if [[ "$MSG" == disabled* ]]; then
    write_log "Suspend disabled. Nothing to do."
    exit 0
fi

if [[ "$MSG" == enabled* ]]; then
    when_suspend_enabled
    exit 0
fi

if [[ "$MSG" == "suspend after"* ]]; then
    when_suspend_after "$MSG"
    exit 0
fi

if [[ "$MSG" == * ]]; then
    write_log "Unknown message: $MSG"
    exit 5
fi



