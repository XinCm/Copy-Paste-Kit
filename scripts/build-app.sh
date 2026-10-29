#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

BUILD_FLAGS=(-c release --product CopyKit)
if [[ $# -gt 1 ]] || [[ $# -eq 1 && "$1" != "--universal" ]]; then
    echo "Usage: $0 [--universal]" >&2
    exit 1
fi

BINARY_PATHS=()
if [[ "${1:-}" == "--universal" ]]; then
    # Separate builds avoid SwiftPM's multi-architecture dependency on a full Xcode installation.
    for ARCHITECTURE in arm64 x86_64; do
        ARCH_FLAGS=(--triple "$ARCHITECTURE-apple-macosx13.0" --scratch-path ".build/$ARCHITECTURE")
        swift build "${BUILD_FLAGS[@]}" "${ARCH_FLAGS[@]}"
        BINARY_DIRECTORY="$(swift build "${BUILD_FLAGS[@]}" "${ARCH_FLAGS[@]}" --show-bin-path)"
        BINARY_PATHS+=("$BINARY_DIRECTORY/CopyKit")
    done
else
    swift build "${BUILD_FLAGS[@]}"
    BINARY_DIRECTORY="$(swift build "${BUILD_FLAGS[@]}" --show-bin-path)"
    BINARY_PATHS+=("$BINARY_DIRECTORY/CopyKit")
fi

APP_PATH="$PROJECT_ROOT/dist/CopyKit.app"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
xcrun lipo -create "${BINARY_PATHS[@]}" -output "$APP_PATH/Contents/MacOS/CopyKit"
cp "$PROJECT_ROOT/Resources/Info.plist" "$APP_PATH/Contents/Info.plist"
plutil -lint "$APP_PATH/Contents/Info.plist"
codesign --force --sign "${CODE_SIGN_IDENTITY:--}" --options runtime "$APP_PATH"
codesign --verify --strict "$APP_PATH"
echo "Built $APP_PATH"
