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

# Self-heal: a run interrupted by shutdown/reboot leaves a stale .lck whose
# recorded PID no longer exists. Clear it ONLY when that PID is dead AND not
# some other rclone process (guards against PID reuse).
LOCK="$HOME/.cache/rclone/bisync/home_erik_ObsidianVault..nextcloud_erik-external-files_Documents_ObsidianNotes.lck"
if [ -f "$LOCK" ]; then
  recorded_pid="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("PID",""))' "$LOCK" 2>/dev/null || true)"
  if [ -n "$recorded_pid" ] && [ ! -e "/proc/$recorded_pid" ] \
     && ! grep -aq rclone "/proc/$recorded_pid/cmdline" 2>/dev/null; then
    echo "vault-bisync: stale lock from dead PID $recorded_pid; removing" >&2
    "$RCLONE" deletefile "$LOCK"
  else
    echo "vault-bisync: lock present with live PID '${recorded_pid:-?}'; aborting" >&2
    exit 1
  fi
fi

if [ "${1:-}" = "--resync" ]; then
  "$RCLONE" mkdir "$REMOTE"   # idempotent; ensures the target dir exists
  exec "$RCLONE" bisync "$VAULT" "$REMOTE" "${OPTS[@]}" --resync
fi
exec "$RCLONE" bisync "$VAULT" "$REMOTE" "${OPTS[@]}"
