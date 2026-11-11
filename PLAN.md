# Dock Cleanup: plan

A menu bar app. Click its icon (or press Ctrl-Option-D), drag a rectangle over the Dock, let go, confirm, and every app icon inside the rectangle is quit and taken out of the Dock.

## Decisions

| Question | Answer |
|---|---|
| What counts as "in the rectangle" | Any app icon whose frame intersects the rectangle, including individual apps in the Recents section. Only the icons touched are affected. |
| Closed apps that are kept in the Dock | Removed from the Dock. |
| Running apps | Quit normally (same as Cmd-Q), so an app with unsaved work can show its "Save changes?" dialog. Its icon is removed once it has quit. If you cancel the save dialog, the app keeps running and its icon stays. |
| Folders, stacks, minimized windows | Ignored. Apps only. |
| Finder, Trash | Always skipped (macOS doesn't allow removing them). |
| Protected apps | An editable list in the right-click menu. Protected icons are shown greyed out while dragging and are never touched. |
| Safety net | After you let go, a small panel appears above the selection listing the apps, with Cancel (Escape) and Quit & Remove (Return). |
| Start a sweep | Left-click the menu bar icon, or Ctrl-Option-D. Escape or right-click cancels at any point. |
| Open at login | No. |
| Raycast | A Store extension (`raycast/`) that works on its own, without the menu bar app. Its one no-view command runs a Swift helper (`raycast/swift`) built from the same sweep code (`Sources/DockCleanup/Shared`, copied by `scripts/sync-raycast.sh`). Protected apps come from a preference, and Raycast itself is always protected (quitting it would end the command mid-removal). Raycast needs Accessibility. |
| Other launchers | Opening the app while it's running (`applicationShouldHandleReopen`) starts a sweep, so Spotlight and Raycast's own app search work without the extension. Launching it fresh doesn't. |

## How it works

### Reading the Dock
The Dock exposes its icons through the Accessibility API. `AXUIElementCreateApplication(dockPid)` gives one `AXList` whose children are the icons. Each has a subrole (`AXApplicationDockItem`, `AXFolderDockItem`, `AXMinimizedWindowDockItem`, `AXSeparatorDockItem`, `AXTrashDockItem`), a title, an `AXURL` (the .app bundle) and a position and size in top-left-origin screen coordinates. These get converted to Cocoa's bottom-left coordinates for drawing and hit-testing.

This needs the Accessibility permission. The app asks for it on first launch and again if a sweep is started without it.

### The sweep
1. One transparent borderless window per screen at screen-saver level, so it sits above the Dock. Crosshair cursor, set directly on every mouse move and allowed while the app is in the background (the private `SetsCursorInBackground` connection property), because cursor rects only apply once the app is active and a menu bar click doesn't always activate it.
2. Mouse down starts the rectangle, dragging resizes it, and Dock icons under it are highlighted live with a blue rounded square the size of the icon (86% of the Dock tile size, placed 4pt in from the screen edge), or a grey square with a lock for protected ones. The rectangle itself is tinted blue.
3. Mouse up with nothing selected ends the sweep. With something selected, the confirm panel appears.
4. Confirm runs the removal and closes the overlay. Cancel, Escape, right-click or a click outside the panel just closes it.

### Quitting and removing
The Dock's own context menu gives the actions. A closed app kept in the Dock, and any app in Recents, has **Options → Remove from Dock**. A running app kept in the Dock only has a checked **Keep in Dock** and no "Remove from Dock" until it quits. Unchecking "Keep in Dock" on a running app would move it into Recents when it quits, which isn't what we want.

So the order for each selected app is:
1. If it's running, call `terminate()` on every running instance of that bundle and wait until they've all exited (checking every 200 ms, giving up after 2 minutes so a cancelled save dialog doesn't leave a task hanging).
2. Re-read the Dock and look for an icon with the same bundle URL. An app that was neither kept nor recent disappears on its own. One that was kept, or that slid into Recents when it quit, is still there.
3. Open that icon's menu with `AXShowMenu` and press Remove from Dock inside the Options submenu. The submenu's items are readable without opening it, so only the main menu appears, for well under a tenth of a second. (Hiding even that would need either a Dock restart or a screenshot cover with Screen Recording permission; Alara chose to keep the menu and make it fast.)

All apps are quit in parallel. Removals run one at a time, re-reading the Dock before each, because icon positions shift after every removal.

**Fallback.** The menu titles are English. If "Remove from Dock" can't be found (another system language, or a future macOS changes the menu), the app removes matching entries from `persistent-apps` and `recent-apps` in the `com.apple.dock` preferences and restarts the Dock. The icons blink for a second but the result is the same.

### The Raycast helper
Raycast runs each `@raycast` Swift function as a short-lived helper process whose generated entry point is `async`.
`sweepDock` is deliberately synchronous and runs `NSApp.run()` itself: inside an async function, Swift's main executor
stops the main run loop while AppKit is handling events, and the process exits mid-sweep. It returns the names of the
apps that actually quit and left the Dock, and the command shows them in a HUD.

### Focus
When a sweep ends, focus goes back to the app that was in front before it. The app tracks the last other app to activate
(`NSWorkspace.didActivateApplicationNotification`), because a link or a reopen brings Dock Cleanup forward before the
sweep starts.

### Protected apps
Stored in UserDefaults as bundle paths. The right-click menu has a "Protected Apps" submenu: each protected app (click to unprotect), then "Add App…" which opens a file picker in /Applications.

## Code layout

```
Package.swift
build.sh                     builds "Dock Cleanup.app", signs it with the Apple Development identity
Sources/DockCleanup/
  main.swift                 app entry, accessory activation policy
  AppDelegate.swift          status item, right-click menu, hotkey, permission check
  Dock.swift                 read Dock icons, remove one via its menu, defaults fallback
  Sweep.swift                overlay windows, drag rectangle, highlights
  ConfirmPanel.swift         SwiftUI panel above the selection
  Remover.swift              quit, wait, remove
  Protected.swift            protected-apps store
  HotKey.swift               Carbon global hotkey (needs no extra permission)
```

Signing with a stable identity matters: an ad-hoc signature changes on every build and macOS silently drops the Accessibility permission each time.

## Edge cases
- Dock on the left or right: frames come from the Dock itself, so it works. The confirm panel goes beside the selection instead of above it.
- Dock auto-hide: not handled yet (off on this Mac). If the Dock is hidden when a sweep starts, nothing is under the rectangle.
- Several instances of one app (e.g. two copies running): all are quit.
- The rectangle can start anywhere on screen, it doesn't have to start on the Dock.

## Testing
Tested on macOS 26.5 with a throwaway app built in a temp folder:
- Running app not kept in the Dock: quit, icon gone, not left in Recents.
- Running app kept in the Dock: quit, then removed through Options → Remove from Dock. The Dock didn't restart.
- Full sweep driven with synthetic mouse and key events: Ctrl-Option-D, the hint, the red highlight, the confirm panel, Escape to cancel, Return to confirm, focus going back to the previous app.
- 30 sweeps in a row, cancelled by Escape, an empty drag and right-click: the app stays running and the menu bar icon stays.
- Multi-app selection with a protected app: the panel lists the others with icons, and the protected one shows grey with a lock.

Not tested yet: a closed app in Recents (macOS didn't add the test app to Recents), the preferences fallback, a Dock on the left or right, more than one display.
