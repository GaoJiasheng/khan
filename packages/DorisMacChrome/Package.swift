// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DorisMacChrome",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "DorisMacChrome", targets: ["DorisMacChrome"])
    ],
    dependencies: [
        .package(path: "../DorisCore"),
        .package(url: "https://github.com/MrKai77/DynamicNotchKit", from: "1.1.0"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "DorisMacChrome",
            dependencies: [
                .product(name: "DorisIPC", package: "DorisCore"),
                .product(name: "DynamicNotchKit", package: "DynamicNotchKit"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")
            ],
            path: "Sources/DorisMacChrome"
        )
    ]
)
