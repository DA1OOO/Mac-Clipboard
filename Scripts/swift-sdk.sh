#!/usr/bin/env bash

configure_swift_sdk() {
    local root_dir="$1"

    export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$root_dir/.build/ModuleCache}"
    mkdir -p "$CLANG_MODULE_CACHE_PATH"

    if [[ -n "${SDKROOT:-}" ]]; then
        return
    fi

    local probe_file="$root_dir/.build/swiftui-sdk-probe.swift"
    mkdir -p "$root_dir/.build"
    cat >"$probe_file" <<'EOF'
import SwiftUI

struct SwiftUIProbeView: View {
  @State private var value = 0

  var body: some View {
    Text("\(value)")
  }
}
EOF

    sdk_supports_swiftui() {
        SDKROOT="$1" swiftc -typecheck "$probe_file" >/dev/null 2>&1
    }

    local default_sdk=""
    if command -v xcrun >/dev/null 2>&1; then
        default_sdk="$(xcrun --sdk macosx --show-sdk-path 2>/dev/null || true)"
    fi

    local sdk
    for sdk in "$default_sdk" $(sdk_candidates "$default_sdk"); do
        [[ -n "$sdk" && -d "$sdk" ]] || continue
        if sdk_supports_swiftui "$sdk"; then
            export SDKROOT="$sdk"
            return
        fi
    done
}

sdk_candidates() {
    local excluded="$1"
    local sdk_root="/Library/Developer/CommandLineTools"

    if [[ -n "$excluded" ]]; then
        local sdk_dir
        sdk_dir="$(dirname "$excluded")"
        if [[ "$(basename "$sdk_dir")" == "SDKs" ]]; then
            sdk_root="$(dirname "$sdk_dir")"
        fi
    fi

    local candidate version
    ls -1d "$sdk_root"/SDKs/MacOSX*.sdk 2>/dev/null \
        | while read -r candidate; do
            version="$(basename "$candidate" | sed -e 's/^MacOSX//' -e 's/\.sdk$//')"
            echo "$version $candidate"
        done \
        | sort -rn \
        | while read -r _ candidate; do
            [[ "$candidate" == "$excluded" ]] && continue
            echo "$candidate"
        done
}
