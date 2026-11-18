#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APK_PATH="$SCRIPT_DIR/NoxSnapAndroid/app/build/outputs/apk/debug/app-debug.apk"

if [ ! -f "$APK_PATH" ]; then
    echo "🔨 Building NoxSnap APK..."
    cd "$SCRIPT_DIR/NoxSnapAndroid" && ./gradlew assembleDebug
fi

echo "📱 Installing NoxSnap APK to connected device..."
adb install -r -t "$APK_PATH"
adb shell am start -n com.naveen.noxsnap/.MainActivity
echo "✅ NoxSnap installed and launched successfully!"
