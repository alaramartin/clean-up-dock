// Copied from Sources/CleanUpDock/Shared/Cursor.swift by scripts/sync-raycast.sh. Edit the original, then run the script.

import AppKit

// Lets the app change the cursor even when it isn't the active app, so the crosshair always shows
// when a sweep starts. Private CoreGraphics call, used by screenshot and window-manager apps.
@_silgen_name("_CGSDefaultConnection") private func _CGSDefaultConnection() -> Int32
@_silgen_name("CGSSetConnectionProperty") private func CGSSetConnectionProperty(_ cid: Int32, _ target: Int32, _ key: CFString, _ value: CFTypeRef) -> Int32

func allowCursorChangesInBackground() {
    let cid = _CGSDefaultConnection()
    _ = CGSSetConnectionProperty(cid, cid, "SetsCursorInBackground" as CFString, kCFBooleanTrue)
}
