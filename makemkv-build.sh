#!/usr/bin/env bash

set -euo pipefail

#prompt user for a version number
read -p "Enter the version number of MakeMKV to build (e.g., 1.17.3): " VERSION_NUMBER

# Verify that files with the version number exist in the current directory
MAKEMVK_TAR_BIN="makemkv-bin-$VERSION_NUMBER.tar.gz"
MAKEMVK_TAR_OSS="makemkv-oss-$VERSION_NUMBER.tar.gz"

if [[ ! -f "$MAKEMVK_TAR_BIN" ]]; then
    echo "Error: $MAKEMVK_TAR_BIN not found in the current directory."
    exit 1
fi

if [[ ! -f "$MAKEMVK_TAR_OSS" ]]; then
    echo "Error: $MAKEMVK_TAR_OSS not found in the current directory."
    exit 1
fi

gunzip -c "$MAKEMVK_TAR_BIN" | tar xz
gunzip -c "$MAKEMVK_TAR_OSS" | tar xz

MAKEMKV_BIN_DIR="makemkv-bin-$VERSION_NUMBER"
MAKEMKV_OSS_DIR="makemkv-oss-$VERSION_NUMBER"

BIN_DIR="bin"
OSS_DIR="oss"

mv "$MAKEMKV_BIN_DIR" "$BIN_DIR"
mv "$MAKEMKV_OSS_DIR" "$OSS_DIR"

pushd "$OSS_DIR"
./configure
make
popd

pushd "$BIN_DIR"
make
popd

tar cf makemkv-$VERSION_NUMBER.tar.gz bin oss

echo "Done."
echo ""
echo "Next steps:"
echo "1. Copy 'makemkv-$VERSION_NUMBER.tar.gz' to your target system."
echo "2. Extract the tarball: tar xf makemkv-$VERSION_NUMBER.tar.gz"
echo "3. Navigate to the 'oss' directory and run: sudo make install"
echo "4. Navigate to the 'bin' directory and run: sudo make install"