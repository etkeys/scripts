#!/bin/bash

set -e

BACKUP_KEY_ENC="$2"
RESTORE_DIR="${3:-/tmp/restore-`date '+%y%m%d'`}"
TAR_BALL_ENC="$1"

if [ -z "$TAR_BALL_ENC" ] ; then
    echo "Missing argument 1: encrypted tar ball"
    exit 1
fi
if [ -z "$BACKUP_KEY_ENC" ] ; then
    echo "Missing argument 2: encrypted backup key file"
    exit 1
fi
if [ -z "$3" ] ; then
    echo "Missing argument 3: restore dir. Will use default $RESTORE_DIR"
fi
if [ ! -d "$RESTORE_DIR" ] ; then
    mkdir -p "$RESTORE_DIR"
fi

BACKUP_KEY="${BACKUP_KEY_ENC%.*}"
TAR_BALL="${TAR_BALL_ENC%.*}"

echo "BACKUP_KEY=$BACKUP_KEY"
echo "BACKUP_KEY_ENC=$BACKUP_KEY_ENC"
echo "RESTORE_DIR=$RESTORE_DIR"
echo "TAR_BALL=$TAR_BALL"
echo "TAR_BALL_ENC=$TAR_BALL_ENC"

gpg --decrypt --output "$BACKUP_KEY" "$BACKUP_KEY_ENC"

# ENTER PRIVATE KEY PASSPHRASE

gpg --pinentry-mode loopback --decrypt --cipher-algo AES --output "$TAR_BALL" --passphrase "$(cat $BACKUP_KEY)" "$TAR_BALL_ENC"

tar xzf "$TAR_BALL" --directory "$RESTORE_DIR"

rm "$BACKUP_KEY_ENC" "$TAR_BALL_ENC" "$TAR_BALL" 
shred -u "$BACKUP_KEY"
