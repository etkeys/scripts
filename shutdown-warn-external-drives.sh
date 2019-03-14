#!/bin/bash

partdrives=$(lsblk -lp | grep -cE "\/dev\/sd[b-z][0-9].+part */")
cryptdrives=$(lsblk -lp | grep -cE "\/dev.+crypt */")
alldrives=$(( $partdrives + $cryptdrives ))

if (( $alldrives > 0 )); then
    notify-send "External drive connected" "An unexpected external drive is still connected. It may not be safe to shutdown before the device is disconnected."
    dmenu-prompt critical "External device still connected. Shutdown anyway?" "shutdown now"
else
    shutdown now
fi

