#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/Scripts/swift-sdk.sh"
configure_swift_sdk "$ROOT_DIR"

cd "$ROOT_DIR"
exec swift run MacClipboard --scratch-path .build
