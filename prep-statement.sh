#!/bin/bash

set -e

OUTPUT_FILE="$(mktemp)"

sed "/^[^0-9]/d" "$1" | awk -F"," '{print $1","$NF}' | sed "/,[^\-]/d" > "$OUTPUT_FILE"
echo "$OUTPUT_FILE" 
