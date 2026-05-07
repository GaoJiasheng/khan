// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "KhanMacChrome",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "KhanMacChrome", targets: ["KhanMacChrome"])
    ],
    dependencies: [
        .package(path: "../KhanCore"),
        .package(url: "https://github.com/MrKai77/DynamicNotchKit", from: "1.1.0"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "KhanMacChrome",
            dependencies: [
                .product(name: "KhanIPC", package: "KhanCore"),
                .product(name: "DynamicNotchKit", package: "DynamicNotchKit"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")
            ],
            path: "Sources/KhanMacChrome"
        )
    ]
)
