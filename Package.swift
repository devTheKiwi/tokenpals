// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TokenPals",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "TokenPals",
            path: "Sources/TokenPals"
        )
    ]
)
