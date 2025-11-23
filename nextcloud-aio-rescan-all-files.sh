#!/usr/bin/env bash

docker exec -u www-data nextcloud-aio-nextcloud php occ files:scan --all