// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "khan",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "khan", targets: ["khan"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.4.0"),
        .package(path: "../../packages/KhanCore")
    ],
    targets: [
        .executableTarget(
            name: "khan",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "KhanIPC", package: "KhanCore")
            ],
            path: "Sources/khan"
        ),
        .testTarget(
            name: "khanTests",
            dependencies: ["khan"],
            path: "Tests/khanTests"
        )
    ]
)
