#!/usr/bin/env bash

DOWNLOAD_DIR="$HOME/Downloads"
RELEASES_URL="https://api.github.com/repos/nextcloud-releases/desktop/releases?per_page=20"
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

# Returns 0 (true) if version $1 is strictly greater than version $2.
version_gt() {
    [ "$1" == "$2" ] && return 1
    [ "$(printf '%s\n%s' "$1" "$2" | sort -V | tail -n1)" == "$1" ]
}

get_installed_version() {
    if [ -x "$LAUNCH_FILE" ]; then
        timeout 10 "$LAUNCH_FILE" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1
    fi
}

RELEASES_JSON=$(curl -L -s "$RELEASES_URL" -H "Accept: application/vnd.github+json" -H "X-Github-Api-Version: 2022-11-28")

if [ $? -ne 0 ] || [ -z "$RELEASES_JSON" ]; then
    echo "Failed to fetch Nextcloud Desktop releases"
    notify "Failed to fetch Nextcloud Desktop releases"
    launch
fi

# Ignore GitHub's "prerelease" flag (it isn't always set correctly) and instead
# detect release-candidate/beta/alpha tags by name, e.g. v35.0.0-rc1.
LATEST_STABLE_RELEASE=$(echo "$RELEASES_JSON" | \
    jq -c '[.[] | select(.draft == false) | select(.tag_name | test("(?i)-(rc|beta|alpha|pre|dev)[0-9]*$") | not)] | first')

if [ -z "$LATEST_STABLE_RELEASE" ] || [ "$LATEST_STABLE_RELEASE" == "null" ]; then
    echo "No stable Nextcloud Desktop release found"
    notify "No stable Nextcloud Desktop release found"
    launch
fi

TO_DOWNLOAD_URL=$(echo "$LATEST_STABLE_RELEASE" | jq -r '.assets[] | select(.name | endswith("AppImage")) | .browser_download_url')
LATEST_VERSION=$(echo "$LATEST_STABLE_RELEASE" | jq -r '.tag_name' | sed 's/^v//')

if [ -z "$TO_DOWNLOAD_URL" ]; then
    echo "Failed to find Nextcloud Desktop AppImage in latest stable release"
    notify "Failed to find Nextcloud Desktop AppImage in latest stable release"
    launch
fi

INSTALLED_VERSION=$(get_installed_version)

if [ -f "$LAUNCH_FILE" ] && [ -n "$INSTALLED_VERSION" ] && [ -n "$LATEST_VERSION" ]; then
    if ! version_gt "$LATEST_VERSION" "$INSTALLED_VERSION"; then
        echo "Installed Nextcloud Desktop AppImage ($INSTALLED_VERSION) is already up-to-date with latest release ($LATEST_VERSION)"
        launch
    fi
fi

wget -v -P "$DOWNLOAD_DIR" "$TO_DOWNLOAD_URL"

if [ -f "$LAUNCH_FILE" ]; then
    mv -v "$LAUNCH_FILE" "$LAUNCH_FILE.old"
fi

DOWNLOADED_FILE=$(ls -t -1 "$DOWNLOAD_DIR"/Nextcloud*.AppImage | head -n 1)

mv -v "$DOWNLOADED_FILE" "$LAUNCH_FILE"
chmod -v +x "$LAUNCH_FILE"

launch
