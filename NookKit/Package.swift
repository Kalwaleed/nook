// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NookKit",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "NookKit", targets: ["NookKit"]),
    ],
    targets: [
        .target(name: "NookKit"),
        .testTarget(name: "NookKitTests", dependencies: ["NookKit"]),
    ]
)
