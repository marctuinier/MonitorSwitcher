#!/bin/bash
set -euo pipefail

APP_NAME="MonitorSwitcher"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

cd "$(dirname "$0")"

rm -rf "$BUILD_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

echo "Compiling..."
swiftc -O \
    -parse-as-library \
    -o "$APP_BUNDLE/Contents/MacOS/$APP_NAME" \
    -target arm64-apple-macos13 \
    Sources/MonitorSwitcher.swift

cp Resources/Info.plist "$APP_BUNDLE/Contents/Info.plist"

# Ad-hoc sign so Gatekeeper allows launch
codesign --force --deep --sign - "$APP_BUNDLE"

echo ""
echo "✓ Built $APP_BUNDLE"
echo ""
echo "Run with:"
echo "  open $APP_BUNDLE"
echo ""
echo "Or install to /Applications:"
echo "  cp -r $APP_BUNDLE /Applications/"
