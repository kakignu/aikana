#!/bin/bash
# Build a double-clickable macOS installer (.pkg) that installs AIかな into
# /Library/Input Methods (system-wide, admin required). Usage: ./make-pkg.sh [version]
#
# Uses productbuild with a distribution that restricts installation to the
# local-system domain so it always lands in /Library (root-owned, the standard
# location for system input methods) — never relocated into ~/Library.
set -euo pipefail

cd "$(dirname "$0")"

VERSION="${1:-0.2}"
ID="com.kakinuma.inputmethod.AIKana"
APP="build/AIKana.app"
PKGROOT="build/pkgroot"
COMPONENT="build/AIKana-component.pkg"
DIST="build/distribution.xml"
PKG="dist/AIKana-${VERSION}.pkg"

echo ">>> building app"
./build.sh >/dev/null

echo ">>> staging payload"
rm -rf "$PKGROOT"
mkdir -p "$PKGROOT"
cp -R "$APP" "$PKGROOT/"
chmod +x pkg-scripts/postinstall

echo ">>> building component pkg"
pkgbuild \
    --root "$PKGROOT" \
    --identifier "$ID" \
    --version "$VERSION" \
    --install-location "/Library/Input Methods" \
    --scripts pkg-scripts \
    "$COMPONENT"

echo ">>> writing distribution.xml (local-system domain only)"
cat > "$DIST" <<XML
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>AIかな</title>
    <domains enable_anywhere="false" enable_currentUserHome="false" enable_localSystem="true"/>
    <options customize="never" require-scripts="true" rootVolumeOnly="true"/>
    <choices-outline>
        <line choice="default"><line choice="$ID"/></line>
    </choices-outline>
    <choice id="default"/>
    <choice id="$ID" visible="false">
        <pkg-ref id="$ID"/>
    </choice>
    <pkg-ref id="$ID" version="$VERSION" onConclusion="none">AIKana-component.pkg</pkg-ref>
</installer-gui-script>
XML

mkdir -p dist
echo ">>> building product pkg -> $PKG"
productbuild --distribution "$DIST" --package-path build "$PKG"

echo ">>> done"
ls -lh "$PKG"
