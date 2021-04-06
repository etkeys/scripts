#!/usr/bin/env bash

git branch -vv | grep ": gone]" | cut -d ' ' -f 3 | \
    awk '{ system("git branch -D " $1) }'
