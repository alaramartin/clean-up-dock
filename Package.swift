// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CleanUpDock",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "CleanUpDock", path: "Sources/CleanUpDock")
    ]
)
