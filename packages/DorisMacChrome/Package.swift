// swift-tools-version: 5.10
import PackageDescription
import Foundation

// See DorisCore/Package.swift for the rationale — we remap source
// paths in debug info / __cstring so "khan" (in the worktree path)
// doesn't leak into the shipped binary.
let packageRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let prefixMapFlags: [SwiftSetting] = [
    .unsafeFlags(["-Xfrontend", "-debug-prefix-map",
                  "-Xfrontend", "\(packageRoot)=/doris/packages/DorisMacChrome"]),
    .unsafeFlags(["-Xfrontend", "-file-prefix-map",
                  "-Xfrontend", "\(packageRoot)=/doris/packages/DorisMacChrome"])
]

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
            path: "Sources/DorisMacChrome",
            swiftSettings: prefixMapFlags
        )
    ]
)
