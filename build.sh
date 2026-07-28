#!/bin/bash
set -e

swift build

APP_NAME="Sway"
BUILD_DIR=".build/debug"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"
cp "Info.plist" "$APP_BUNDLE/Contents/"
cp "Sway.icns" "$APP_BUNDLE/Contents/Resources/"
codesign --force --sign - --deep "$APP_BUNDLE"

echo "✅ App bundle created at $APP_BUNDLE"
echo "Run with: open $APP_BUNDLE"
