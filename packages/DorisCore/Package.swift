// swift-tools-version: 5.10
import PackageDescription
import Foundation

// Compute the package root at evaluation time so we can rewrite source
// paths in debug info / __cstring out of the build artifacts. Without
// this, every Debug build embeds full absolute paths
// (`/Users/.../packages/DorisCore/Sources/DorisCore/IPC/IPCDirectory.swift`)
// in the .dylib's `__cstring` section. We map the user's worktree
// path to a generic `/doris` root so `strings` / disassembly / Spotlight
// content scans don't surface the local filesystem layout.
let packageRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let prefixMapFlags: [SwiftSetting] = [
    .unsafeFlags(["-Xfrontend", "-debug-prefix-map",
                  "-Xfrontend", "\(packageRoot)=/doris/packages/DorisCore"]),
    .unsafeFlags(["-Xfrontend", "-file-prefix-map",
                  "-Xfrontend", "\(packageRoot)=/doris/packages/DorisCore"])
]

let package = Package(
    name: "DorisCore",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "DorisCore", targets: ["DorisCore"]),
        .library(name: "DorisIPC", targets: ["DorisIPC"])
    ],
    targets: [
        .target(
            name: "DorisIPC",
            path: "Sources/DorisIPC",
            swiftSettings: prefixMapFlags
        ),
        .target(
            name: "DorisCore",
            dependencies: ["DorisIPC"],
            path: "Sources/DorisCore",
            swiftSettings: prefixMapFlags
        ),
        .testTarget(
            name: "DorisIPCTests",
            dependencies: ["DorisIPC"],
            path: "Tests/DorisIPCTests",
            swiftSettings: prefixMapFlags
        ),
        .testTarget(
            name: "DorisCoreTests",
            dependencies: ["DorisCore"],
            path: "Tests/DorisCoreTests",
            swiftSettings: prefixMapFlags
        )
    ]
)
