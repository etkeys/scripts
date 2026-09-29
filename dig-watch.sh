#!/usr/bin/env bash
# dig-watch.sh — Repeatedly check the ACME challenge TXT record for a domain.
# Wraps the dig command from the Obsidian vault note "Sys Admin/Web Certs".
#
# Usage: ./dig-watch.sh <domain> [interval_seconds]
#        ./dig-watch.sh example.com          (default: refresh every 60s)
#        ./dig-watch.sh example.com 15       (refresh every 15s)
#
# Press Ctrl+C to stop once you see your value in the output.

set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
    echo "Usage: $0 <domain> [interval_seconds]" >&2
    exit 1
fi

DOMAIN="$1"
INTERVAL="${2:-60}"

if ! [[ "$INTERVAL" =~ ^[0-9]+$ ]] || [[ "$INTERVAL" -lt 1 ]]; then
    echo "Interval must be a positive integer (seconds)." >&2
    exit 1
fi

RECORD="_acme-challenge.${DOMAIN}"

echo "Watching TXT record for: $RECORD  (every ${INTERVAL}s, Ctrl+C to stop)"

while true; do
    echo "----- $(date '+%Y-%m-%d %H:%M:%S') -----"
    dig -t TXT "$RECORD" +noall +answer +authority
    sleep "$INTERVAL"
done
