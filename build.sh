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

# Sign with self-signed "Sway Development" certificate if available, otherwise ad-hoc.
# The self-signed cert keeps a stable designated requirement (identifier + cert root),
# so the macOS Accessibility/TCC grant survives rebuilds.
SIGN_IDENTITY="Sway Development"
if security find-identity -p codesigning 2>&1 | grep -q "$SIGN_IDENTITY"; then
    codesign --force --sign "$SIGN_IDENTITY" --deep "$APP_BUNDLE"
else
    echo "⚠️  '$SIGN_IDENTITY' not found, using ad-hoc signature (Accessibility grant may reset on rebuild)"
    codesign --force --sign - --deep "$APP_BUNDLE"
fi

echo "✅ App bundle created at $APP_BUNDLE"
echo "Run with: open $APP_BUNDLE"
