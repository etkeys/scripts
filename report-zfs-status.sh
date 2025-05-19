#!/usr/bin/env bash

set -e
set -u

zpool status -v &&
echo "----------------------" &&
zpool list -v &&
echo "----------------------" &&
zfs list &&
echo "----------------------" &&
zfs list -t snapshot

