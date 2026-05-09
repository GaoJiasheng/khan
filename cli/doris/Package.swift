// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "doris",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "doris", targets: ["doris"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.4.0"),
        .package(path: "../../packages/DorisCore")
    ],
    targets: [
        .executableTarget(
            name: "doris",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "DorisIPC", package: "DorisCore")
            ],
            path: "Sources/doris"
        ),
        .testTarget(
            name: "dorisTests",
            dependencies: ["doris"],
            path: "Tests/dorisTests"
        )
    ]
)
