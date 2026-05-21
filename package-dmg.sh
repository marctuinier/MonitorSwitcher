#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="MonitorSwitcher"
VERSION="${1:-1.0.0}"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
STAGING_DIR="$BUILD_DIR/dmg-staging"
DMG_PATH="$BUILD_DIR/$APP_NAME-$VERSION.dmg"

./build.sh

echo ""
echo "Staging DMG contents..."
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$DMG_PATH"

echo "Creating DMG..."
hdiutil create \
    -volname "$APP_NAME $VERSION" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH" \
    >/dev/null

rm -rf "$STAGING_DIR"

echo ""
echo "✓ DMG ready: $DMG_PATH"
ls -lh "$DMG_PATH"
