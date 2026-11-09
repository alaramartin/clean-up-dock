import AppKit
import RaycastSwiftMacros

// Raycast runs this as a small helper process for each call. sweepDock shows the same overlay as the menu bar app
// (Shared/), waits while you drag and confirm, quits and removes the apps, then returns.

/// True when Raycast has Accessibility access, which the helper needs to read the Dock and remove icons.
@raycast func hasAccessibility() -> Bool {
  AXIsProcessTrusted()
}

struct SweepResult: Encodable {
  /// Names of the apps that were quit and removed. Empty when the sweep was cancelled.
  let removed: [String]
}

/// Runs one sweep. `protectedApps` holds app names or bundle IDs that are never selected.
///
/// This is deliberately not `async`. Raycast's generated entry point awaits async functions on Swift's main
/// executor, which stops the main run loop in ways that make the process exit while the overlay is up. A plain
/// function runs on the main thread before that, so AppKit's own `NSApp.run()` can drive the sweep; work the
/// sweep schedules on the main actor (quitting, removing) still runs, because the run loop services it.
@raycast func sweepDock(protectedApps: [String]) -> SweepResult {
  MainActor.assumeIsolated { SweepResult(removed: runSweep(protectedApps: protectedApps)) }
}

@MainActor private func runSweep(protectedApps: [String]) -> [String] {
  let app = NSApplication.shared
  app.setActivationPolicy(.accessory)
  allowCursorChangesInBackground()

  let protected = Set(protectedApps.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty })
  let isProtected: (DockItem) -> Bool = { item in
    protected.contains(item.title.lowercased()) || item.bundleID.map { protected.contains($0.lowercased()) } == true
  }
  // Raycast has closed its window by now, so the front app is the one to give focus back to.
  let previous = NSWorkspace.shared.frontmostApplication.flatMap { $0.processIdentifier == getpid() ? nil : $0 }

  var removed: [String] = []
  var sweep: Sweep?
  sweep = Sweep(previousApp: previous, isProtected: isProtected, onComplete: { names in
    removed = names
    // Leave NSApp.run(): stop() takes effect after the next event, so post one.
    app.stop(nil)
    if let wake = NSEvent.otherEvent(with: .applicationDefined, location: .zero, modifierFlags: [], timestamp: 0,
                                     windowNumber: 0, context: nil, subtype: 0, data1: 0, data2: 0) {
      app.postEvent(wake, atStart: false)
    }
  })
  // Start once the app is running, so activation and the key window take effect.
  RunLoop.main.perform { MainActor.assumeIsolated { sweep?.start() } }
  app.run()
  sweep = nil
  return removed
}
