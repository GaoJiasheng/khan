// swift-tools-version: 5.10
import PackageDescription

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
            path: "Sources/DorisIPC"
        ),
        .target(
            name: "DorisCore",
            dependencies: ["DorisIPC"],
            path: "Sources/DorisCore"
        ),
        .testTarget(
            name: "DorisIPCTests",
            dependencies: ["DorisIPC"],
            path: "Tests/DorisIPCTests"
        ),
        .testTarget(
            name: "DorisCoreTests",
            dependencies: ["DorisCore"],
            path: "Tests/DorisCoreTests"
        )
    ]
)
