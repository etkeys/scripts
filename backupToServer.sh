#!/bin/bash

LOCAL_DIRS=('Documents' 'Music' 'Pictures' 'Templates' 'Videos' '.secure' '.ssh' '.themes/backup')
LOCAL_HOME="/home/erik" # need this because cron has a different home
LOCAL_SSH_KEY="$LOCAL_HOME/.ssh/keys_AgFoxte"
OPTIONS='-Caiusv -e ssh'
REMOTE_ADDR="erik@toby"
REMOTE_HOME="/home/erik/datastore"
# CMD=''

ExecuteRsynccmd(){
    CMD="rsync $OPTIONS $HOME/$1 $REMOTE_ADDR:$REMOTE_HOME"
    eval "$CMD"
}

pushd "$LOCAL_HOME"

eval `ssh-agent -s`
ssh-add "$LOCAL_SSH_KEY"

for d in "${LOCAL_DIRS[@]}"; do
    if [ -d "$d" ] ; then
        ExecuteRsynccmd "$d"
    fi
done

popd
