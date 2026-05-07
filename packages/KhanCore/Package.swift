// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "KhanCore",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "KhanCore", targets: ["KhanCore"]),
        .library(name: "KhanIPC", targets: ["KhanIPC"])
    ],
    targets: [
        .target(
            name: "KhanIPC",
            path: "Sources/KhanIPC"
        ),
        .target(
            name: "KhanCore",
            dependencies: ["KhanIPC"],
            path: "Sources/KhanCore"
        ),
        .testTarget(
            name: "KhanIPCTests",
            dependencies: ["KhanIPC"],
            path: "Tests/KhanIPCTests"
        ),
        .testTarget(
            name: "KhanCoreTests",
            dependencies: ["KhanCore"],
            path: "Tests/KhanCoreTests"
        )
    ]
)
