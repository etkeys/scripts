#!/usr/bin/env bash
# This script runs a command after a specified delay.
# Usage: run-after-delay.sh <delay_seconds> <command> [command_args...]

# Check if at least two arguments are provided
if [ $# -lt 2 ]; then
    echo "Usage: $0 <delay_seconds> <command> [command_arguments...]"
    exit 1
fi

# First argument is the number of seconds to sleep
sleep_time=$1
shift

# Remaining arguments are the command to execute
command="$@"

# Sleep for specified time
sleep "$sleep_time"

# Execute the command with its arguments
exec $command