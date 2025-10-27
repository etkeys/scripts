#!/usr/bin/env bash

if [ ! -d /usr/local/etc/backup-apps ]; then
    echo "Creating configuration directory for backup-apps..."
    sudo mkdir -p /usr/local/etc/backup-apps
    sudo touch /usr/local/etc/backup-apps/config.yml
    sudo chmod g+w /usr/local/etc/backup-apps/config.yml
    sudo chgrp adm /usr/local/etc/backup-apps/config.yml
fi

if [ ! -d /usr/local/lib/backup-apps ]; then
    echo "Creating directory for support scripts..."
    sudo mkdir -p /usr/local/lib/backup-apps
fi

if [ ! -d /usr/local/lib/systemd/system ]; then
    echo "Creating local systemd system directory..."
    sudo mkdir -p /usr/local/lib/systemd/system
fi

if [ ! -d /var/local/backups ]; then
    echo "Creating backup storage directory..."
    sudo mkdir -p /var/local/backups
    sudo chmod g-w /var/local/backups
    sudo chmod g+s /var/local/backups
    sudo chown root:adm /var/local/backups
fi