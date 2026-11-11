// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DockCleanup",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "DockCleanup", path: "Sources/DockCleanup")
    ]
)
