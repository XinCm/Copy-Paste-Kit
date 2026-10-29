// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CopyKit",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "CopyKit", targets: ["CopyKit"])],
    targets: [
        .executableTarget(name: "CopyKit"),
        .testTarget(name: "CopyKitTests", dependencies: ["CopyKit"]),
    ]
)
