#!/bin/bash

ExecuteRsynccmd(){
    rsynccmd="rsync $options $HOME/$1 $remoteDestination"
    eval "$rsynccmd"
}

localdirs=('bin' 'Documents' 'Music' 'Pictures' 'Templates' 'Videos' 'Workspace' '.secure' '.ssh' '.themes/backup')
options='--progress --protect-args -Cauvi -e ssh'
remoteDestination="erik@duiker:$HOME"
rsynccmd=''

for d in "${localdirs[@]}"; do
    ExecuteRsynccmd "$d"
done
