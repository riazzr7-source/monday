#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "$DIR"

echo "🔨 Building MONDAY in Release mode..."
swift build -c release

APP_NAME="Monday"
BUILD_BIN="$DIR/.build/release/$APP_NAME"
DIST_DIR="$DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"

echo "📦 Creating $APP_NAME.app bundle structure..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_BIN" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

echo "✍️  Ad-hoc code signing..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "✅ Successfully built: $APP_BUNDLE"
echo "📏 App Bundle Size: $(du -sh "$APP_BUNDLE" | cut -f1)"
