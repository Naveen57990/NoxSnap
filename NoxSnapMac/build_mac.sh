#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🔨 Building NoxSnap for macOS in release mode..."
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/NoxSnap"
APP_NAME="NoxSnap.app"
APP_DIR="$SCRIPT_DIR/$APP_NAME"

echo "📦 Packaging $APP_NAME..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/NoxSnap"
cp "$SCRIPT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"

if [ -f "$SCRIPT_DIR/Resources/AppIcon.icns" ]; then
    cp "$SCRIPT_DIR/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

# Copy audio chimes if available
if [ -f "/Users/naveen/Downloads/flick file transfer/FlikMac/Resources/ArrivalChime.wav" ]; then
    cp "/Users/naveen/Downloads/flick file transfer/FlikMac/Resources/ArrivalChime.wav" "$APP_DIR/Contents/Resources/ArrivalChime.wav"
fi

echo "✍️ Signing NoxSnap with stable identifier..."
codesign -s - --force --deep --identifier "com.naveen.noxsnap.mac" "$APP_DIR"

echo "🚀 Installing to /Applications/NoxSnap.app..."
pkill -9 -f "NoxDock" 2>/dev/null || true
pkill -9 -f "NoxSnap" 2>/dev/null || true
rm -rf "/Applications/NoxSnap.app"
cp -R "$APP_DIR" "/Applications/NoxSnap.app"

echo "✅ Installed successfully to /Applications/NoxSnap.app"
