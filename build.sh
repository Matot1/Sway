#!/bin/bash
set -e

swift build

APP_NAME="Sway"
BUILD_DIR=".build/debug"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Frameworks" "$APP_BUNDLE/Contents/Resources"
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"
cp "Info.plist" "$APP_BUNDLE/Contents/"
cp "Sway.icns" "$APP_BUNDLE/Contents/Resources/"

# Embed Sparkle framework
cp -R "$BUILD_DIR/Sparkle.framework" "$APP_BUNDLE/Contents/Frameworks/"
# Add rpath so the executable can find Sparkle.framework
install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_BUNDLE/Contents/MacOS/$APP_NAME" 2>/dev/null || true

codesign --force --sign - --deep "$APP_BUNDLE"

echo "✅ App bundle created at $APP_BUNDLE"
echo "Run with: open $APP_BUNDLE"
