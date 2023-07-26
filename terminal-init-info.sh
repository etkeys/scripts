#!/bin/bash

printf "%s - %s (%s %s %s)\n" "$(lsb_release -sd)" "$(lsb_release -sc)" "$(uname -o)" "$(uname -r)" "$(uname -m)"  
cat /var/lib/update-notifier/updates-available
