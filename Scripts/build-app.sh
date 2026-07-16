#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/MacClipboard.app"
FALLBACK_SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"

if [[ -z "${SDKROOT:-}" && -d "$FALLBACK_SDK" ]]; then
    export SDKROOT="$FALLBACK_SDK"
fi

cd "$ROOT_DIR"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"
install -m 755 "$BIN_DIR/MacClipboard" "$APP_DIR/Contents/MacOS/MacClipboard"
install -m 644 "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
codesign --force --sign - "$APP_DIR"

echo "Built $APP_DIR"

