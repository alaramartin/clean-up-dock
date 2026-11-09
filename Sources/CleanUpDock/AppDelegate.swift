import AppKit
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hotKey: HotKey?
    private var sweep: Sweep?

    func applicationDidFinishLaunching(_ note: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "rectangle.dashed", accessibilityDescription: "Clean Up Dock")
            button.toolTip = "Clean Up Dock: click, then drag over Dock icons (⌃⌥D)"
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        allowCursorChangesInBackground()
        hotKey = HotKey(keyCode: kVK_ANSI_D, modifiers: controlKey | optionKey) { [weak self] in self?.toggleSweep() }

        if !AXIsProcessTrusted() {
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(opts)
        }
    }

    @objc private func clicked() {
        let e = NSApp.currentEvent
        if e?.type == .rightMouseUp || e?.modifierFlags.contains(.control) == true {
            sweep?.cancel()
            statusItem.menu = makeMenu()
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            // Next run loop turn: the status button resets the cursor while it finishes handling the click.
            DispatchQueue.main.async { self.toggleSweep() }
        }
    }

    @objc private func toggleSweep() {
        if let sweep { sweep.cancel(); return }
        guard AXIsProcessTrusted() else { askForAccessibility(); return }
        let s = Sweep { [weak self] finished in
            if self?.sweep === finished { self?.sweep = nil }
        }
        sweep = s
        s.start()
    }

    private func askForAccessibility() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Clean Up Dock needs Accessibility access"
        alert.informativeText = "It uses Accessibility to find the icons in your Dock and remove them. Turn on Clean Up Dock in System Settings → Privacy & Security → Accessibility, then try again."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }

    // MARK: - Menu

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        let sweepItem = NSMenuItem(title: "Clean Up Dock", action: #selector(toggleSweep), keyEquivalent: "d")
        sweepItem.keyEquivalentModifierMask = [.control, .option]
        sweepItem.target = self
        menu.addItem(sweepItem)
        menu.addItem(.separator())

        let protectedItem = NSMenuItem(title: "Protected Apps", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        let ids = Protected.bundleIDs.sorted { Protected.displayName($0).localizedCaseInsensitiveCompare(Protected.displayName($1)) == .orderedAscending }
        if ids.isEmpty {
            let none = NSMenuItem(title: "None", action: nil, keyEquivalent: "")
            none.isEnabled = false
            sub.addItem(none)
        }
        for id in ids {
            let item = NSMenuItem(title: Protected.displayName(id), action: #selector(unprotect(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = id
            item.image = Protected.icon(id)
            item.state = .on
            item.toolTip = "Click to stop protecting it"
            sub.addItem(item)
        }
        sub.addItem(.separator())
        let add = NSMenuItem(title: "Add App…", action: #selector(addProtected), keyEquivalent: "")
        add.target = self
        sub.addItem(add)
        protectedItem.submenu = sub
        menu.addItem(protectedItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Clean Up Dock", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    @objc private func unprotect(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? String { Protected.remove(id) }
    }

    @objc private func addProtected() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.title = "Protect Apps"
        panel.message = "Clean Up Dock will never quit or remove these apps."
        panel.prompt = "Protect"
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let id = Bundle(url: url)?.bundleIdentifier { Protected.add(id) }
        }
    }
}

// Lets the app change the cursor even when it isn't the active app, so the crosshair always shows
// when a sweep starts. Private CoreGraphics call, used by screenshot and window-manager apps.
@_silgen_name("_CGSDefaultConnection") private func _CGSDefaultConnection() -> Int32
@_silgen_name("CGSSetConnectionProperty") private func CGSSetConnectionProperty(_ cid: Int32, _ target: Int32, _ key: CFString, _ value: CFTypeRef) -> Int32

func allowCursorChangesInBackground() {
    let cid = _CGSDefaultConnection()
    _ = CGSSetConnectionProperty(cid, cid, "SetsCursorInBackground" as CFString, kCFBooleanTrue)
}
