#!/usr/bin/env bash
# Plex Media Server Backup Script
#
# This script creates a compressed backup of the Plex Media Server configuration 
# and metadata, excluding cache, logs, and database journal files.
#
# Prerequisites:
# - Must be run with sudo/root privileges
# - BACKUP_DIR environment variable must be set to the destination backup directory
#
# Environment Variables:
# - BACKUP_DIR: Target directory for storing backups (required)
# - PLEX_SERVER_DIR: Optional custom path to Plex Media Server directory
#
# Usage:
#   sudo BACKUP_DIR=/path/to/backups ./backup-plex-media-server.sh
#
# Exits:
# - 1: Not running as root
# - 2: Backup directory does not exist
# - 3: Error creating tar archive

set -e
set -u


FINAL_DIR="${BACKUP_DIR:?backup dir environment variable not set}"
PLEX_SERVER_DIR="${PLEX_SERVER_DIR:-/var/snap/plexmediaserver/common/Library/Application Support/Plex Media Server}"
TIMESTAMP=$(date +%y%m%d)
TEMP_FILE="/tmp/plexmediaserver.$TIMESTAMP.tar.gz"

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Please use sudo."
  exit 1
fi

if [ ! -d "$FINAL_DIR" ]; then
  echo "Backup directory '$FINAL_DIR' does not exist. Please create it."
  exit 2
fi

tar -czf "$TEMP_FILE" \
  --exclude='Plex Media Server/Cache/*' \
  --exclude='Plex Media Server/Logs/*' \
  --exclude='Plex Media Server/Plug-in Support/Databases/com.plexapp.plugins.library.db-shm' \
  --exclude='Plex Media Server/Plug-in Support/Databases/com.plexapp.plugins.library.db-wal' \
  --exclude='Plex Media Server/Plug-in Support/Databases/com.plexapp.plugins.library.db-journal' \
  --exclude='Plex Media Server/Plug-in Support/Databases/com.plexapp.plugins.library.db' \
  -C "$PLEX_SERVER_DIR" \
  ./
if [ $? -ne 0 ]; then
    echo "Error creating tar archive. Please check the Plex Media Server directory."
    exit 3
fi

mv "$TEMP_FILE" "$FINAL_DIR/."

COUNT_FILES=$(ls -1 "$FINAL_DIR" | wc -l)
while [ $COUNT_FILES -gt 10 ]; do
  OLDEST_FILE=$(ls -1 "$FINAL_DIR" | head -1)
  echo "Removing oldest backup file: $OLDEST_FILE"
  rm "$FINAL_DIR/$OLDEST_FILE"
  COUNT_FILES=$(ls -1 "$FINAL_DIR" | wc -l)
done

echo "Done."