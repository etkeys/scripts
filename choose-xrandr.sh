#!/bin/bash

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
pushd "$HOME/.config/xrandr"

# active monitor bitmasks
_NO_MON=0
_MON1=1
_MON2=2
_MON3=4
 
actSetup=$_NO_MON
currDef=$(readlink "current")
edp=$(xrandr -q | grep "^eDP-1-1")
hdmi1=$(xrandr -q | grep "^HDMI-1-1")
hdmi2=$(xrandr -q | grep "^HDMI-1-2")

printverbose "$edp"
printverbose "$hdmi1"
printverbose "$hdmi2"

addsetup(){
    if echo "$1" | grep -Eq "[^s]connected"; then
        actSetup=$(( $actSetup | $2 ))
    fi
}

normalizesetup(){
    if (( $actSetup > ( $_MON2 | $_MON3 ) )) ; then
        # If all three monintors are availalbe, turn off MON1
        actSetup=$(($_MON2 | $_MON3))

    elif (( $actSetup < $_MON1 )) ; then
        actSetup=$_MON1

    fi
}

addsetup "$edp" $_MON1
addsetup "$hdmi1" $_MON2
addsetup "$hdmi2" $_MON3
normalizesetup
printverbose "Actual setup mask: $actSetup"

# If the current definition begins with actual
# setup, then exit because everything is correct
printverbose "currDef: $currDef"
if echo "$currDef" | grep -Eq "^$actSetup-" ; then
    printverbose "Definition matches. Nothing to do."
    popd
    exit 0
fi

# Current definition does not match actual setup
# Get a new definition that is appropriate

newDef="$(ls | grep "^$actSetup-")"
printverbose "newDef: $newDef"
ln -sfnv "$newDef" "current"

#i3-msg "restart"
popd
