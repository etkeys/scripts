#!/usr/bin/env bash
# Obsidian vault <-> Nextcloud bisync. Staged by Dax (hermes) 2026-09-27.
# Usage: vault-bisync.sh            normal incremental run
#        vault-bisync.sh --resync   first run / rebuild baseline
# Created by Dax (Hermes Agent)
set -euo pipefail
RCLONE="/home/erik/.local/bin/rclone"
VAULT="/home/erik/ObsidianVault"
REMOTE="nextcloud:erik-external-files/Documents/ObsidianNotes"
FILTERS="/home/erik/.config/rclone/vault-filters.txt"
OPTS=(--filters-file "$FILTERS" --resilient --recover --verbose
      --conflict-resolve newer --conflict-loser pathname)
if [ "${1:-}" = "--resync" ]; then
  "$RCLONE" mkdir "$REMOTE"   # idempotent; ensures the target dir exists
  exec "$RCLONE" bisync "$VAULT" "$REMOTE" "${OPTS[@]}" --resync
fi
exec "$RCLONE" bisync "$VAULT" "$REMOTE" "${OPTS[@]}"
