#!/bin/bash
# Build a double-clickable macOS installer (.pkg) that installs AIかな into
# /Library/Input Methods (system-wide). Usage: ./make-pkg.sh [version]
set -euo pipefail

cd "$(dirname "$0")"

VERSION="${1:-0.1}"
APP="build/AIKana.app"
PKGROOT="build/pkgroot"
PKG="dist/AIKana-${VERSION}.pkg"

echo ">>> building app"
./build.sh >/dev/null

echo ">>> staging payload"
rm -rf "$PKGROOT"
mkdir -p "$PKGROOT"
cp -R "$APP" "$PKGROOT/"

chmod +x pkg-scripts/postinstall

mkdir -p dist
echo ">>> building $PKG"
pkgbuild \
    --root "$PKGROOT" \
    --identifier com.kakinuma.inputmethod.AIKana \
    --version "$VERSION" \
    --install-location "/Library/Input Methods" \
    --scripts pkg-scripts \
    "$PKG"

echo ">>> done"
ls -lh "$PKG"
