#!/bin/bash

wd="$XDG_CONFIG_HOME/xrandr"

if [ "$1" == '-v' ] ; then
    passedVerbose=true
fi
pVerbose=${passedVerbose:-false}

printverbose(){
    if $pVerbose; then
        echo "$1"
    fi
}

# Race condition with monitors becoming active and this
# script executing. It can lead to reading incorrect setup.
# So sleep for a moment to make sure this script runs later.
sleep 2;
pushd "$wd"

# Count the number of monitors connected
moncount="$(xrandr -q | grep -cE "[^s]connected")"

# What is currently set
currDef=$(readlink "$wd" | grep -Eo "^.")


# If the current definition begins with actual
# setup, then exit because everything is correct
printverbose "Current setup: $currDef"
printverbose "Actual setup: $moncount"
if [ "$currDef" == "$moncount" ] ; then
    printverbose "Definition matches. Nothing to do."
    popd
    exit 0
fi

# Current definition does not match actual setup
# Get a new definition that is appropriate

newDef="$(ls | grep "^$moncount")"
printverbose "newDef: $newDef"
ln -sfnv "$newDef" "current"

#i3-msg "restart"
popd
