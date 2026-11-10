import AppKit

/// Lets the app change the cursor even when it isn't the active app, so the crosshair always shows when a sweep
/// starts. It uses a private CoreGraphics setting (also used by screenshot and window-manager apps), looked up at
/// runtime so that if a future macOS drops it, the sweep still works and only this convenience is lost.
func allowCursorChangesInBackground() {
    typealias DefaultConnection = @convention(c) () -> Int32
    typealias SetProperty = @convention(c) (Int32, Int32, CFString, CFTypeRef) -> Int32
    guard let handle = dlopen(nil, RTLD_NOW),
          let getConnection = dlsym(handle, "_CGSDefaultConnection"),
          let setProperty = dlsym(handle, "CGSSetConnectionProperty") else { return }
    let cid = unsafeBitCast(getConnection, to: DefaultConnection.self)()
    _ = unsafeBitCast(setProperty, to: SetProperty.self)(cid, cid, "SetsCursorInBackground" as CFString, kCFBooleanTrue)
}
