#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

swift build -Xswiftc -warnings-as-errors
./scripts/test.sh
plutil -lint Resources/Info.plist
bash -n scripts/build-app.sh scripts/check.sh scripts/test.sh
if xcrun --find swift-format >/dev/null 2>&1; then
    xcrun swift-format lint --strict --recursive Sources Tests Package.swift
fi
