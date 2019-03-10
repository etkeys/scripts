#!/bin/bash

# Original source
# https://github.com/LukeSmithxyz/voidrice/blob/master/.scripts/i3cmds/ducksearch

# Gives a dmenu prompt to search DuckDuckGo.
# Without input, will open DuckDuckGo.com.
# URLs will be directly handed to the browser.
# Anything else, it search it.
browser=${BROWSER:-firefox}
engine="https://duckduckgo.com"

pgrep -x dmenu && exit

choice=$(echo "?" | dmenuw "dmenu -p 'Search:'") || exit 1

if [ "$choice" = "?"  ]; then
    $browser "$engine"
else
    # Detect if url
    if [[ "$choice" =~ ^(http:\/\/|https:\/\/)?[a-zA-Z0-9]+\.[a-zA-Z]+(/)?.*$ ]]; then
        $browser "$choice"
    else
        $browser "$engine?q=$choice&t=ffab&atb=v1-1"
    fi
fi
