#!/bin/bash

# Original source
# https://github.com/LukeSmithxyz/voidrice/blob/master/.scripts/i3cmds/ducksearch

# Gives a dmenu prompt to search DuckDuckGo.
# Without input, will open DuckDuckGo.com.
# URLs will be directly handed to the browser.
# Anything else, it search it.
browser=${BROWSER:-x-www-browser}
engine="https://youtube.com"

pgrep -x dmenu && exit

# choice=$(echo "?" | dmenuw "dmenu -p 'Youtube search:'") || exit 1
choice="$(dmenu-style --prompt 'Youtube search:' --choose 1 '?' -- echo)" || exit 1

if [ "$choice" = "?"  ]; then
    $browser "$engine"
else
    choice=$(echo "$choice" | sed -e "s/ /\+/g")
    $browser "$engine/results?search_query=$choice"
fi
