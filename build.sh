#!/bin/bash
# Builds "Dock Cleanup.app" (universal: Apple silicon + Intel).
#   --install   also move it to /Applications and launch it
#   --zip       also make build/DockCleanup.zip for a GitHub release
set -euo pipefail
cd "$(dirname "$0")"

# Version = the newest release tag (v1.2.1 → 1.2.1), unless VERSION is set. scripts/release.sh sets it for a new release.
git fetch --tags -q 2>/dev/null || true
LATEST_TAG="$(git describe --tags --abbrev=0 --match 'v[0-9]*' 2>/dev/null || true)"
VERSION="${VERSION:-${LATEST_TAG#v}}"
VERSION="${VERSION:-0.0.0}"
swift build -c release --arch arm64 --arch x86_64
BIN=".build/apple/Products/Release/DockCleanup"
APP="build/Dock Cleanup.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/DockCleanup"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Dock Cleanup</string>
    <key>CFBundleDisplayName</key><string>Dock Cleanup</string>
    <key>CFBundleIdentifier</key><string>com.alaramartin.dock-cleanup</string>
    <key>CFBundleExecutable</key><string>DockCleanup</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSUIElement</key><true/>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key><string>com.alaramartin.dock-cleanup</string>
            <key>CFBundleURLSchemes</key><array><string>dockcleanup</string></array>
        </dict>
    </array>
</dict>
</plist>
PLIST
# Sign with a stable identity when there is one, so macOS keeps the Accessibility permission across
# rebuilds (an ad-hoc signature changes every build, which silently revokes it). Override with SIGN_ID.
SIGN_ID="${SIGN_ID:-$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Apple Development|Developer ID Application/ {print $2; exit}')}"
codesign --force --sign "${SIGN_ID:--}" "$APP"
echo "Built $APP"

if [[ " $* " == *" --zip "* ]]; then
    rm -f build/DockCleanup.zip
    ditto -c -k --keepParent "$APP" build/DockCleanup.zip
    echo "Zipped build/DockCleanup.zip"
fi

if [[ " $* " == *" --install "* ]]; then
    pkill -x DockCleanup || true
    rm -rf "/Applications/Dock Cleanup.app"
    mv "$APP" /Applications/
    open "/Applications/Dock Cleanup.app"
    echo "Installed to /Applications and launched"
fi
