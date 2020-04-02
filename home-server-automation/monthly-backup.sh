#!/bin/bash

set -e

while getopts ":d:r:u:" args; do
    case "${args}" in 
        d) 
            SOURCE_DIR="${OPTARG}"
            ;;
        r)
            RECIPIENT="${OPTARG}"
            ;;
        u)
            UPLOAD_TARGETS="${OPTARG}"
            ;;
    esac
done

if [ -z "$RECIPIENT" ] ; then
    echo "GPG recipient not specified, exiting"
    exit 1
fi

BACKUP_DATE=$(date "+%y%m%d")
BACKUP_DIR='/tmp'
BACKUP_KEY="$BACKUP_DIR/monthly-backup-$BACKUP_DATE.key"
BACKUP_KEY_ENC="$BACKUP_KEY.gpg"
SOURCE_DIR="${SOURCE_DIR:-/datastore/}"
TAR_BALL="$BACKUP_DIR/monthly-backup-$BACKUP_DATE.tgz.gpg"
UPLOAD_TARGETS="${UPLOAD_TARGETS:-/tmp/monthly-backup-$BACKUP_DATE.targets}"

echo "BACKUP_DATE=$BACKUP_DATE"
echo "BACKUP_DIR=$BACKUP_DIR"
echo "BACKUP_KEY=$BACKUP_KEY"
echo "BACKUP_KEY_ENC=$BACKUP_KEY_ENC"
echo "SOURCE_DIR=$SOURCE_DIR"
echo "TAR_BALL=$TAR_BALL"
echo "UPLOAD_TARGETS=$UPLOAD_TARGETS"

cat /dev/null > $UPLOAD_TARGETS
echo "$BACKUP_KEY_ENC" >> $UPLOAD_TARGETS
echo "$TAR_BALL" >> $UPLOAD_TARGETS

dd if=/dev/urandom bs=16 count=1 2>/dev/null | base64 > $BACKUP_KEY

tar cz "$SOURCE_DIR" | \
   gpg --pinentry-mode loopback --symmetric --cipher-algo AES --output "$TAR_BALL" --passphrase "$(cat $BACKUP_KEY)" 

gpg --encrypt --recipient "$RECIPIENT" --output "$BACKUP_KEY_ENC" "$BACKUP_KEY"

shred -u "$BACKUP_KEY"

