#!/bin/bash

if lsblk | grep -Eq "sd[b-z][0-9]" ; then
    notify-send "External drive connected" "An unexpected external drive is still connected. It may not be safe to shutdown before the device is disconnected."
    dmenu-prompt critical "External device still connected. Shutdown anyway?" "shutdown now"
else
    shutdown now
fi
