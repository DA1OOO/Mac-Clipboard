#!/usr/bin/env bash

configure_swift_sdk() {
    local root_dir="$1"
    local fallback_sdk="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
    local default_sdk=""

    export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$root_dir/.build/ModuleCache}"
    mkdir -p "$CLANG_MODULE_CACHE_PATH"

    if [[ -n "${SDKROOT:-}" ]]; then
        return
    fi

    if command -v xcrun >/dev/null 2>&1; then
        default_sdk="$(xcrun --sdk macosx --show-sdk-path 2>/dev/null || true)"
    fi

    local sdk
    for sdk in "$default_sdk" "$fallback_sdk"; do
        [[ -n "$sdk" && -d "$sdk" ]] || continue
        if SDKROOT="$sdk" swiftc -typecheck - >/dev/null 2>&1 <<< 'let sdkProbe = true'; then
            export SDKROOT="$sdk"
            return
        fi
    done
}
