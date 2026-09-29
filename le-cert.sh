#!/usr/bin/env bash
# le-cert.sh — Create/renew a Let's Encrypt cert via the manual ACME DNS challenge.
# Wraps the command from the Obsidian vault note "Sys Admin/Web Certs".
#
# Usage: sudo ./le-cert.sh -d example.com [-d www.example.com ...]
#        sudo ./le-cert.sh --test -d example.com          (staging server, no rate limits)
#
# Notes:
# - One cert per run: pass multiple -d flags to include SANs (e.g. wildcard + base),
#   but don't use one run for unrelated certs.
# - You'll be prompted to create a TXT record for _acme-challenge.<domain>.
#   Use dig-watch.sh in another terminal to watch it propagate.

set -euo pipefail

SERVER="https://acme-v02.api.letsencrypt.org/directory"

usage() {
    sed -n '2,10p' "$0"
    exit 0
}

[[ $# -eq 0 ]] && usage

for arg in "$@"; do
    case "$arg" in
        --test) SERVER="https://acme-staging-v02.api.letsencrypt.org/directory" ;;
        -h|--help) usage ;;
    esac
done

if [[ $EUID -ne 0 ]]; then
    echo "Run with sudo (certbot writes to /etc/letsencrypt)." >&2
    exit 1
fi

if ! command -v certbot >/dev/null 2>&1; then
    echo "certbot not found. Install: sudo snap install certbot --classic" >&2
    exit 1
fi

sudo certbot certonly \
    --manual \
    --preferred-challenges dns \
    --server "$SERVER" \
    "$@"
