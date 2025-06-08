#!/usr/bin/env bash

set -e

LIST_ALL_SNAPSHOTS=false

print_core_status() {
    zpool status -v &&
    echo "----------------------" &&
    zpool list -v &&
    echo "----------------------" &&
    zfs list
}

print_snapshot_status() {
    echo "----------------------"

    if [ "$LIST_ALL_SNAPSHOTS" = true ]; then
        zfs list -t snapshot
    else
        zfs list -t snapshot -o name |
            tail -n+2 |
            cut -d '@' -f 2 |
            sort |
            uniq |
            while read -r snapshot; do
                echo "@$snapshot"
            done
    fi
}

print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --snapshots      List all snapshots instead of a summary"
    echo "  -h, --help       Display this help message and exit"
}

for arg in "$@"; do
    case "$arg" in
        --snapshots)
            LIST_ALL_SNAPSHOTS=true
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $arg" >&2
            print_usage >&2
            exit 1
            ;;
    esac
done

if [ "$LIST_ALL_SNAPSHOTS" = false ]; then
    print_core_status
fi
print_snapshot_status
