#!/bin/sh

SSHSPEC="$1"

scp -r .bash_aliases .bashrc .profile .vim .vimrc "$SSHSPEC"
