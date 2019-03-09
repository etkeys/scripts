#!/bin/bash

printf "%s - %s (%s %s %s)\n" "$(lsb_release -sd)" "$(lsb_release -sc)" "$(uname -o)" "$(uname -r)" "$(uname -m)"  
/etc/update-motd.d/50-landscape-sysinfo
/etc/update-motd.d/90-updates-available
printf "\n"
