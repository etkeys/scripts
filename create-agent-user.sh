#!/usr/bin/env bash

USERNAME=""
PUBLIC_KEY=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --username)
            USERNAME="$2"
            shift 2
            ;;
        --public-key)
            PUBLIC_KEY="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 --username <username> --public-key <public_key>"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 --username <username> --public-key <public_key>"
            exit 2
            ;;
    esac
done

if [ -z "$USERNAME" ]; then
    echo "Error: --username is required"
    exit 1
fi
if [ -z "$PUBLIC_KEY" ]; then
    echo "Error: --public-key is required"
    exit 1
fi

PUBLIC_KEY="$PWD/$PUBLIC_KEY"

if [ ! -f "$PUBLIC_KEY" ]; then
    echo "Error: Public key file '$PUBLIC_KEY' does not exist"
    exit 1
fi

if ! id -u "$USERNAME" &>/dev/null; then
    echo "Creating user: $USERNAME"
    sudo useradd --create-home --shell /bin/bash "$USERNAME"
else
    echo "User $USERNAME already exists"
fi

if [ ! -d "/home/$USERNAME/.ssh" ]; then
    echo "Creating .ssh directory for user: $USERNAME"
    sudo mkdir -p "/home/$USERNAME/.ssh"
fi

sudo mv "$PUBLIC_KEY" "/home/$USERNAME/.ssh/authorized_keys"
sudo chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.ssh"
sudo chmod g-rwx,o-rwx "/home/$USERNAME/.ssh"

echo "You must now set the password for the user $USERNAME."
sudo passwd "$USERNAME"