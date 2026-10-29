#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

if xcrun swiftc -typecheck - <<< 'import Testing' >/dev/null 2>&1; then
    swift test -Xswiftc -warnings-as-errors
else
    echo "Swift Testing is unavailable; running the same checks with the standalone runner."
    SOURCES=()
    while IFS= read -r source; do
        SOURCES+=("$source")
    done < <(find Sources Tests -name '*.swift' ! -name 'CopyKitApp.swift' -print | sort)
    mkdir -p .build
    xcrun swiftc -swift-version 6 -parse-as-library -D COPYKIT_STANDALONE -warnings-as-errors \
        "${SOURCES[@]}" -o .build/CopyKitChecks
    .build/CopyKitChecks
fi
