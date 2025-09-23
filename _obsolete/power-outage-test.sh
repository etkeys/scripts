#!/usr/bin/env bash

# Power Outage Detection and Shutdown Script
#
# Monitors network connectivity to specified beacon devices and initiates
# a graceful system shutdown if network connectivity is lost. Intended to
# be executed using a systemd service/timer or cron job to periodically check
#
# Features:
# - Checks reachability of multiple network beacon devices
# - Uses a flag file to prevent multiple shutdown attempts
# - Provides a one-minute shutdown grace period
# - Automatically clears shutdown flag when network is restored
#
# Prerequisites:
# - Must be run with sudo/root privileges
# - Requires network connectivity to specified beacon devices
# - Ping utility must be installed
#
# Usage:
#   sudo ./power-outage-test.sh
#
# Configuration:
# - BEACON1: Primary network device IP to check
# - BEACON2: Secondary network device IP to check
# - FLAG_FILE: Temporary file to track shutdown state
#
# Exit Codes:
# - 0: Normal execution
# - 1: Not running with root privileges
#
# Behavior:
# - If no beacons are reachable and no flag exists: Create flag file
# - If no beacons are reachable and flag exists: Initiate shutdown
# - If beacons are reachable and flag exists: Remove flag file

BEACON1="192.168.1.200"
BEACON2="192.168.1.201"
FLAG_FILE="/tmp/power-outage-test.flag"

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root."
  exit 1
fi

check_beacon() {
    local beacon_ip="$1"
    if ping -c 2 -W 2 "$beacon_ip" &> /dev/null; then
        echo "Beacon $beacon_ip is reachable."
        return 0
    else
        echo "Beacon $beacon_ip is not reachable."
        return 1
    fi
}

if ! check_beacon "$BEACON1" && ! check_beacon "$BEACON2"; then

    if [ -e "$FLAG_FILE" ]; then
        echo "Flag file exists, beginning shutdown."
        shutdown -P +1m "Power outage detected, shutting down in 1 minute."
        exit 0
    else
        echo "No flag file found, creating one."
        echo "Power outage detected, creating flag file for shutdown."
        touch "$FLAG_FILE"
        exit 0
    fi

else
    echo "At least one beacon is reachable."

    if [ ! -e "$FLAG_FILE" ]; then
        echo "Nothing to do."
        exit 0
    fi

    echo "Removing flag file."
    rm -f "$FLAG_FILE"

    exit 0
fi