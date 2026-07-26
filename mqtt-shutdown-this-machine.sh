#!/usr/bin/env bash
#
# mqtt-shutdown-this-machine.sh
#
# Polls an MQTT topic for a retained shutdown message. If found, clears
# the retained message and cleanly shuts down the Pi via systemd.

set -euo pipefail

: "${MQTT_HOST:?MQTT_HOST is not set}"
: "${MQTT_USER:?MQTT_USER is not set}"
: "${MQTT_PASS:?MQTT_PASS is not set}"
: "${MQTT_TOPIC:?MQTT_TOPIC is not set}"

SHUTDOWN_PAYLOAD="${MQTT_SHUTDOWN_PAYLOAD:-SHUTDOWN}"
WAIT_SECONDS="${MQTT_WAIT_SECONDS:-5}"

LOG_TAG="mqtt-shutdown-this-machine"

# Grab a single message from the topic. Since we expect this to be a
# *retained* message, mosquitto_sub receives it immediately on subscribe,
# so a short timeout is sufficient.
MESSAGE="$(mosquitto_sub \
    -h "$MQTT_HOST" \
    -u "$MQTT_USER" \
    -P "$MQTT_PASS" \
    -t "$MQTT_TOPIC" \
    -C 1 \
    -W "$WAIT_SECONDS" \
    2>/dev/null)" || MESSAGE=""

if [[ "$MESSAGE" == "$SHUTDOWN_PAYLOAD" ]]; then
    logger -t "$LOG_TAG" "Received '$MESSAGE' on '$MQTT_TOPIC' -- clearing retained message and shutting down."

    # Clear the retained message so we don't immediately shut down again
    # the next time the Pi boots.
    mosquitto_pub \
        -h "$MQTT_HOST" \
        -u "$MQTT_USER" \
        -P "$MQTT_PASS" \
        -t "$MQTT_TOPIC" \
        -r -n

    systemctl poweroff
else
    logger -t "$LOG_TAG" "No shutdown command present on '$MQTT_TOPIC' (got '${MESSAGE:-<empty>}')."
fi