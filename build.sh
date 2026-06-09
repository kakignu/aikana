#!/bin/bash
# Build AIKana.app (an InputMethodKit input method) from the Swift sources.
set -euo pipefail

cd "$(dirname "$0")"

APP="build/AIKana.app"
EXEC_NAME="AIKana"

echo ">>> cleaning"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo ">>> compiling Swift sources"
swiftc -O \
    -target arm64-apple-macos13 \
    -framework Cocoa -framework InputMethodKit \
    -o "$APP/Contents/MacOS/$EXEC_NAME" \
    Sources/*.swift

echo ">>> assembling bundle"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AIKana.icns Resources/AIKana.tiff "$APP/Contents/Resources/" 2>/dev/null || true
cp -R Resources/*.lproj "$APP/Contents/Resources/" 2>/dev/null || true
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo ">>> ad-hoc code signing"
codesign --force --deep --sign - "$APP"

echo ">>> built $APP"
codesign -dv "$APP" 2>&1 | sed 's/^/    /' || true
