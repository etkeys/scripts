#!/bin/bash

ExecuteRsynccmd(){
    rsynccmd="rsync $options $HOME/$1 $remoteDestination"
    eval "$rsynccmd"
}

pushd '/home/erik'

localdirs=('bin' 'Documents' 'Music' 'Pictures' 'Templates' 'Videos' '.secure' '.ssh' '.themes/backup')
options='--progress --protect-args -Cauvi -e ssh'
remoteDestination="erik@duiker:$HOME"
rsynccmd=''

for d in "${localdirs[@]}"; do
    ExecuteRsynccmd "$d"
done

popd
