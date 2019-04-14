#!/bin/bash

HOME="/home/erik"

ExecuteRsynccmd(){
    rsynccmd="rsync $options $HOME/$1 $remoteDestination"
    eval "$rsynccmd"
}

pushd "$HOME"

eval `ssh-agent -s`
ssh-add .ssh/keys_AgFoxte

localdirs=('bin' 'Documents' 'Music' 'Pictures' 'Templates' 'Videos' '.secure' '.ssh' '.themes/backup')
options='--progress --protect-args -Cauvi -e ssh'
remoteDestination="erik@duiker:$HOME"
rsynccmd=''

for d in "${localdirs[@]}"; do
    ExecuteRsynccmd "$d"
done

popd
