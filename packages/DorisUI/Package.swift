// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DorisUI",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "DorisUI", targets: ["DorisUI"])
    ],
    dependencies: [
        .package(path: "../DorisCore")
    ],
    targets: [
        .target(
            name: "DorisUI",
            dependencies: [
                .product(name: "DorisCore", package: "DorisCore")
            ],
            path: "Sources/DorisUI",
            resources: [
                .copy("HeroAnim")
            ]
        )
    ]
)
