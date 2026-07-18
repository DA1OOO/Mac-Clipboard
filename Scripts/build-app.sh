#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/MacClipboard.app"
source "$ROOT_DIR/Scripts/swift-sdk.sh"
configure_swift_sdk "$ROOT_DIR"

cd "$ROOT_DIR"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"
install -m 755 "$BIN_DIR/MacClipboard" "$APP_DIR/Contents/MacOS/MacClipboard"
install -m 644 "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
codesign --force --sign - "$APP_DIR"

echo "Built $APP_DIR"
