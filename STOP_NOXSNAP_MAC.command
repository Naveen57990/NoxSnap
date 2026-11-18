#!/bin/bash
pkill -f "/Applications/NoxSnap.app/Contents/MacOS/NoxSnap" 2>/dev/null || pkill -f "NoxSnap" 2>/dev/null
echo "🛑 NoxSnap for macOS daemon has been stopped."
