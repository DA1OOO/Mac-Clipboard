#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FALLBACK_SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"

if [[ -z "${SDKROOT:-}" && -d "$FALLBACK_SDK" ]]; then
    export SDKROOT="$FALLBACK_SDK"
fi

cd "$ROOT_DIR"
exec swift run MacClipboardSelfTests --scratch-path .build

