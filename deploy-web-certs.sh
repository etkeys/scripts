#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat << EOF
Usage: $(basename "$0") SITE [--remote-host REMOTE_HOST]

Arguments:
  SITE                 The site domain name
  
Options:
  --remote-host REMOTE_HOST
                       Remote host to deploy certificates to
  -h, --help           Show this help message
EOF
    exit "${1:-0}"
}

SITE=""
REMOTE_HOST=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage 0
            ;;
        --remote-host)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --remote-host requires a value" >&2
                usage 1
            fi
            REMOTE_HOST="$2"
            shift 2
            ;;
        -*)
            echo "Error: Unknown option $1" >&2
            usage 1
            ;;
        *)
            if [[ -z "$SITE" ]]; then
                SITE="$1"
            else
                echo "Error: Unexpected argument $1" >&2
                usage 1
            fi
            shift
            ;;
    esac
done

# Validate required arguments
if [[ -z "$SITE" ]]; then
    echo "Error: SITE argument is required" >&2
    usage 1
fi

if [[ -z "$REMOTE_HOST" ]]; then
    echo "--remote-host not specified, copying files to destination on this machine."

    sudo mkdir -vp /etc/caddy/certs/"$SITE"
    sudo mv -v ./*.pem /etc/caddy/certs/"$SITE"/.
    sudo chown -vR root:caddy /etc/caddy/certs
    sudo chmod -vR u+rwX,g+rX,go-w,o-rx /etc/caddy/certs

    sudo systemctl restart caddy
    echo "Caddy server restarted to apply new certificates."
else
    echo "Deploying certificates to remote host: $REMOTE_HOST"

    pushd "$(mktemp -d)"

    sudo cp -vL /etc/letsencrypt/live/"$SITE"/fullchain.pem .
    sudo cp -vL /etc/letsencrypt/live/"$SITE"/privkey.pem .
    sudo chmod -v 644 ./*.pem

    if scp ./*.pem $REMOTE_HOST:.; then
        echo "Certificates deployed successfully."
        sudo shred -uz ./*.pem
        popd
    else
        echo "Failed to deploy certificates." >&2
        exit 1
    fi
fi

exit 0
