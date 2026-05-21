#!/usr/bin/env bash

TEMP=$(sudo storcli /c0 show temperature | grep "temperature" | grep -oP '\d+')
if [ -z "$TEMP" ]; then
    echo "Unable to retrieve HBA temperature."
    exit 1
fi
echo "HBA Temperature: $TEMP"