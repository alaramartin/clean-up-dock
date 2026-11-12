#!/bin/bash
# Copies the sweep code shared by the menu bar app and the Raycast extension into raycast/swift.
# Raycast publishes only the raycast/ folder, so the extension carries its own copy. Run after editing Sources/DockCleanup/Shared.
set -euo pipefail
cd "$(dirname "$0")/.."
DEST=raycast/swift/Sources/DockCleanup/Shared
rm -rf "$DEST"
mkdir -p "$DEST"
for f in Sources/DockCleanup/Shared/*.swift; do
    { echo "// Shared with the Dock Cleanup menu bar app: https://github.com/alaramartin/dock-cleanup/blob/main/$f"; echo; cat "$f"; } > "$DEST/$(basename "$f")"
done
echo "Copied $(ls "$DEST" | wc -l | tr -d ' ') files to $DEST"
