#!/bin/sh
# Dependencies/idevice builds IDevice.xcframework from Rust, which the Swift package expects to
# find already built. Rather than requiring a Rust toolchain and cross-compilation targets, fetch
# the prebuilt xcframework published by the upstream project.
#
# Usage: Scripts/fetch-idevice-xcframework.sh [version]

set -e

VERSION="${1:-v0.1.64}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/Dependencies/idevice/swift"
URL="https://github.com/jkcoxson/idevice/releases/download/$VERSION/idevice-xcframework-$VERSION.zip"

if [ -d "$DEST/IDevice.xcframework" ]; then
    echo "IDevice.xcframework already present; delete it to re-fetch."
    exit 0
fi

if [ ! -d "$DEST" ]; then
    echo "error: $DEST is missing. Run: git submodule update --init --recursive" >&2
    exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Fetching idevice $VERSION..."
curl -fL --progress-bar -o "$TMP/idevice.zip" "$URL"

# The archive contains swift/IDevice.xcframework, so unpack it over Dependencies/idevice.
unzip -q "$TMP/idevice.zip" -d "$ROOT/Dependencies/idevice"

test -d "$DEST/IDevice.xcframework"
echo "Installed $DEST/IDevice.xcframework"
