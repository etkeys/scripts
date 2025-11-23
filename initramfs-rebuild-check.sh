#!/usr/bin/env bash

# Initramfs Rebuild Check Script
# This script checks if any installed packages require an initramfs
# rebuild by simulating an upgrade and searching for initramfs-related changes.

sudo apt upgrade --simulate | grep -i initramfs