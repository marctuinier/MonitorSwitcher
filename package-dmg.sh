#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="MonitorSwitcher"
VERSION="${1:-1.0.0}"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DMG_NAME="$APP_NAME-$VERSION.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"

./build.sh

rm -f "$DMG_PATH"

echo ""
echo "Creating DMG..."
create-dmg \
    --volname "$APP_NAME $VERSION" \
    --window-size 540 360 \
    --icon-size 110 \
    --icon "$APP_NAME.app" 140 170 \
    --app-drop-link 400 170 \
    --no-internet-enable \
    "$DMG_PATH" \
    "$APP_BUNDLE"

echo ""
echo "✓ DMG ready: $DMG_PATH"
