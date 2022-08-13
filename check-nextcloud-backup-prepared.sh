#!/usr/bin/env bash

PATH=/bin:/usr/bin:/sbin
HOME=/home/erik
BACKUP_DIR="${HOME}/nextcloud_backup"
NOTIFY_EXPIRE=10000
NOTIFY_SUBJECT='Nextcloud object storage backup'
REMOTE="rudolph"

function send_notification() {
    local MESSAGE="${1}"
    notify-send \
       --urgency critical \
       --expire-time ${NOTIFY_EXPIRE} \
       --category backup \
       "${NOTIFY_SUBJECT}" \
       "${MESSAGE}"
}

ssh -l erik -i "${HOME}/.ssh/cron" "${REMOTE}" [ -e "${BACKUP_DIR}" ] 2> /dev/null
RET=$?
case ${RET} in
    0)
        # success, do nothing
        ;;
    1)
        send_notification "Backup drive not present on machine '${REMOTE}'!"
        ;;
    255)
        send_notification "Cannot connect to machine '${REMOTE}'!"
        ;;
    *)
        send_notification "Unexpected result! Cannot determine backup setup."
        ;;
esac

exit ${RET}


