#!/bin/bash
# Builds "Clean Up Dock.app" (universal: Apple silicon + Intel).
#   --install   also move it to /Applications and launch it
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${VERSION:-0.1.0}"
swift build -c release --arch arm64 --arch x86_64
BIN=".build/apple/Products/Release/CleanUpDock"
APP="build/Clean Up Dock.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/CleanUpDock"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Clean Up Dock</string>
    <key>CFBundleDisplayName</key><string>Clean Up Dock</string>
    <key>CFBundleIdentifier</key><string>com.alaramartin.clean-up-dock</string>
    <key>CFBundleExecutable</key><string>CleanUpDock</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST
# Sign with a stable identity when there is one, so macOS keeps the Accessibility permission across
# rebuilds (an ad-hoc signature changes every build, which silently revokes it). Override with SIGN_ID.
SIGN_ID="${SIGN_ID:-$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Apple Development|Developer ID Application/ {print $2; exit}')}"
codesign --force --sign "${SIGN_ID:--}" "$APP"
echo "Built $APP"

if [[ " $* " == *" --install "* ]]; then
    pkill -x CleanUpDock || true
    rm -rf "/Applications/Clean Up Dock.app"
    mv "$APP" /Applications/
    open "/Applications/Clean Up Dock.app"
    echo "Installed to /Applications and launched"
fi
