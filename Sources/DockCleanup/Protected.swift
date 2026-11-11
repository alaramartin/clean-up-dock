import AppKit

/// Apps a sweep never touches, saved by bundle ID.
enum Protected {
    private static let key = "protectedBundleIDs"

    static var bundleIDs: [String] {
        get { UserDefaults.standard.stringArray(forKey: key) ?? [] }
        set { UserDefaults.standard.set(Array(Set(newValue)).sorted(), forKey: key) }
    }

    static func contains(_ item: DockItem) -> Bool {
        guard let id = item.bundleID else { return false }
        return bundleIDs.contains(id)
    }

    static func add(_ id: String) { bundleIDs.append(id) }
    static func remove(_ id: String) { bundleIDs.removeAll { $0 == id } }

    static func displayName(_ id: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return id }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    static func icon(_ id: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return nil }
        let img = NSWorkspace.shared.icon(forFile: url.path)
        img.size = NSSize(width: 16, height: 16)
        return img
    }
}
