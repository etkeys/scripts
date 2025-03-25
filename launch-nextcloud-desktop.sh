#!/usr/bin/env bash

DOWNLOAD_DIR="$HOME/Downloads"
HISTORY_FILE="$HOME/.config/nextcloud-desktop-download-history.txt"
LATEST_RELEASE_URL="https://api.github.com/repos/nextcloud-releases/desktop/releases/latest"
LAUNCH_FILE="$HOME/.local/bin/nextcloud-desktop.AppImage"

notify() {
    notify-send "Nextcloud Desktop AppImage" "$1" -u critical
}

launch() {
    if [ -f "$LAUNCH_FILE" ]; then
        echo "Launching Nextcloud Desktop AppImage"
        nohup "$LAUNCH_FILE" > /tmp/nextcloud-desktop.AppImage.log 2>&1 &
        exit 0
    else
        echo "Nextcloud Desktop AppImage not found"
        notify "Nextcloud Desktop AppImage not found"
        exit 2
    fi
}

TO_DOWNLOAD_URL=$(
    curl -L "$LATEST_RELEASE_URL" -H "Accept: application/vnd.github+json" -H "X-Github-Api-Version: 2022-11-28" | \
        jq -r '.assets[] | select(.name | endswith("AppImage")) | .browser_download_url')

if [ $? -ne 0 ]; then
    echo "Failed to download Nextcloud Desktop AppImage"
    notify "Failed to download Nextcloud Desktop AppImage"
    launch
fi

if [ -f "$LAUNCH_FILE" ] && [ -f "$HISTORY_FILE" ]; then
    HISTORY_DOWNLOAD_URL=$(cat "$HISTORY_FILE")

    if [ "$TO_DOWNLOAD_URL" == "$HISTORY_DOWNLOAD_URL" ]; then
        echo "Nextcloud Desktop AppImage is up-to-date"
        launch
    fi
fi

wget -v -P "$DOWNLOAD_DIR" "$TO_DOWNLOAD_URL"
echo "$TO_DOWNLOAD_URL" > "$HISTORY_FILE"

if [ -f "$LAUNCH_FILE" ]; then
    mv -v "$LAUNCH_FILE" "$LAUNCH_FILE.old"
fi

DOWNLOADED_FILE=$(ls -t -1 "$DOWNLOAD_DIR"/Nextcloud*.AppImage | head -n 1)

mv -v "$DOWNLOADED_FILE" "$LAUNCH_FILE"
chmod -v +x "$LAUNCH_FILE"

launch
