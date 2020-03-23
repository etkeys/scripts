#!/bin/sh
# This script will make the updates-available data file used by motd readable
# by any user. This is helpful for scripts that fetch data via ssh but do are
# not user login shells (e.g. ssh-getstats).
#
# This script is designed to be ran from root cron.

TARGET_FILE='/var/lib/update-notifier/updates-available'

if [ -f $TARGET_FILE ] ; then
    chmod o+r "$TARGET_FILE"
fi
