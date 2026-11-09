import AppKit

/// One drag-to-select session: overlay windows on every screen, the rectangle, the highlights and the confirm panel.
final class Sweep {
    private let items: [DockItem]
    private var windows: [OverlayWindow] = []
    private var panel: ConfirmPanel?
    private let previousApp = NSWorkspace.shared.frontmostApplication
    private let onFinish: (Sweep) -> Void

    /// The drag rectangle in global Cocoa coordinates, while the mouse is down.
    private(set) var rect: NSRect?
    private(set) var selected: [DockItem] = []
    private(set) var protectedHits: [DockItem] = []
    var isConfirming: Bool { panel != nil }

    init(onFinish: @escaping (Sweep) -> Void) {
        items = Dock.appItems().filter(\.isRemovable)
        self.onFinish = onFinish
    }

    /// The area covered by the Dock's app icons.
    var dockFrame: NSRect? { items.dropFirst().reduce(items.first?.frame) { $0?.union($1.frame) } }

    /// The screen showing the Dock, used for the hint and the confirm panel.
    var dockScreen: NSScreen? {
        guard let f = items.first?.frame else { return NSScreen.main }
        return NSScreen.screens.first { $0.frame.intersects(f) } ?? NSScreen.main
    }

    func start() {
        for screen in NSScreen.screens {
            let w = OverlayWindow(screen: screen, sweep: self)
            windows.append(w)
            w.orderFrontRegardless()
        }
        NSApp.activate(ignoringOtherApps: true)
        windows.first { $0.screen == dockScreen }?.makeKey()
        NSCursor.crosshair.push()
    }

    // MARK: - Drag

    private var anchor: NSPoint?

    func mouseDown(at p: NSPoint) {
        if isConfirming { cancel(); return }
        anchor = p
        update(to: p)
    }

    func mouseDragged(to p: NSPoint) { update(to: p) }

    func mouseUp(at p: NSPoint) {
        guard anchor != nil else { return }
        update(to: p)
        anchor = nil
        rect = nil
        redraw()
        if selected.isEmpty { cancel() } else { confirm() }
    }

    private func update(to p: NSPoint) {
        guard let a = anchor else { return }
        let r = NSRect(x: min(a.x, p.x), y: min(a.y, p.y), width: abs(a.x - p.x), height: abs(a.y - p.y))
        rect = r
        let hits = items.filter { $0.frame.intersects(r) || $0.frame.contains(a) }
        selected = hits.filter { !Protected.contains($0) }
        protectedHits = hits.filter { Protected.contains($0) }
        redraw()
    }

    private func redraw() { windows.forEach { $0.contentView?.needsDisplay = true } }

    // MARK: - Confirm

    private func confirm() {
        let p = ConfirmPanel(items: selected, onConfirm: { [weak self] in self?.commit() },
                             onCancel: { [weak self] in self?.cancel() })
        p.place(near: selected.map(\.frame).reduce(selected[0].frame) { $0.union($1) }, on: dockScreen)
        p.makeKeyAndOrderFront(nil)
        panel = p
        NSCursor.pop()
    }

    private func commit() {
        let apps = selected.map(\.ref)
        teardown(restoreFocus: false)
        Task { @MainActor in
            await Remover.run(apps)
            // Give focus back to whatever was in front, unless it was just quit.
            if let prev = previousApp, !prev.isTerminated, !apps.contains(where: { $0.matches(prev) }) {
                prev.activate()
            }
        }
    }

    func cancel() { teardown(restoreFocus: true) }

    private func teardown(restoreFocus: Bool) {
        if panel == nil { NSCursor.pop() }
        panel?.close()
        panel = nil
        windows.forEach { $0.contentView = nil; $0.close() }
        windows.removeAll()
        if restoreFocus { previousApp?.activate() }
        onFinish(self)
    }
}

// MARK: - Overlay

final class OverlayWindow: NSWindow {
    init(screen: NSScreen, sweep: Sweep) {
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        setFrame(screen.frame, display: false)
        level = .screenSaver
        isOpaque = false
        // Nearly clear, not fully clear: fully transparent pixels let clicks fall through to the windows below.
        backgroundColor = NSColor(white: 0, alpha: 0.001)
        hasShadow = false
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isReleasedWhenClosed = false
        contentView = OverlayView(sweep: sweep, isDockScreen: screen == sweep.dockScreen)
    }
    override var canBecomeKey: Bool { true }
}

final class OverlayView: NSView {
    // Weak: AppKit can still ask a hidden overlay to draw after its sweep has finished and been freed.
    private weak var sweep: Sweep?
    private let isDockScreen: Bool

    init(sweep: Sweep, isDockScreen: Bool) {
        self.sweep = sweep
        self.isDockScreen = isDockScreen
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }

    private func global(_ e: NSEvent) -> NSPoint { window!.convertPoint(toScreen: e.locationInWindow) }
    private func local(_ r: NSRect) -> NSRect { convert(window!.convertFromScreen(r), from: nil) }

    override func mouseDown(with e: NSEvent) { sweep?.mouseDown(at: global(e)) }
    override func mouseDragged(with e: NSEvent) { sweep?.mouseDragged(to: global(e)) }
    override func mouseUp(with e: NSEvent) { sweep?.mouseUp(at: global(e)) }
    override func rightMouseDown(with e: NSEvent) { sweep?.cancel() }
    override func keyDown(with e: NSEvent) {
        if e.keyCode == 53 { sweep?.cancel() } else { super.keyDown(with: e) }
    }

    override func draw(_ dirty: NSRect) {
        guard let sweep else { return }
        for item in sweep.protectedHits {
            let r = local(item.frame).insetBy(dx: 3, dy: 3)
            NSColor(white: 0.1, alpha: 0.55).setFill()
            NSBezierPath(roundedRect: r, xRadius: 12, yRadius: 12).fill()
            if let lock = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: "Protected")?
                .withSymbolConfiguration(.init(pointSize: 16, weight: .semibold).applying(.init(paletteColors: [.white]))) {
                let s = lock.size
                lock.draw(in: NSRect(x: r.midX - s.width / 2, y: r.midY - s.height / 2, width: s.width, height: s.height))
            }
        }
        for item in sweep.selected {
            let r = local(item.frame).insetBy(dx: 3, dy: 3)
            let path = NSBezierPath(roundedRect: r, xRadius: 12, yRadius: 12)
            NSColor.systemRed.withAlphaComponent(0.28).setFill()
            path.fill()
            NSColor.systemRed.setStroke()
            path.lineWidth = 2
            path.stroke()
        }
        if let g = sweep.rect {
            let r = local(g)
            NSColor.white.withAlphaComponent(0.12).setFill()
            r.fill()
            NSColor.white.withAlphaComponent(0.85).setStroke()
            let path = NSBezierPath(rect: r.insetBy(dx: 0.5, dy: 0.5))
            path.lineWidth = 1
            path.stroke()
        }
        if isDockScreen && sweep.rect == nil && !sweep.isConfirming {
            drawHint(sweep)
        }
    }

    private func drawHint(_ sweep: Sweep) {
        let text = "Drag over Dock icons to quit and remove them. Esc cancels."
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13, weight: .medium), .foregroundColor: NSColor.white]
        let size = (text as NSString).size(withAttributes: attrs)
        let dock = sweep.dockFrame.map(local) ?? NSRect(x: bounds.midX, y: 0, width: 0, height: 80)
        let box = NSRect(x: dock.midX - size.width / 2 - 14, y: dock.maxY + 20, width: size.width + 28, height: size.height + 14)
        NSColor(white: 0, alpha: 0.7).setFill()
        NSBezierPath(roundedRect: box, xRadius: box.height / 2, yRadius: box.height / 2).fill()
        (text as NSString).draw(at: NSPoint(x: box.minX + 14, y: box.minY + 7), withAttributes: attrs)
    }
}
