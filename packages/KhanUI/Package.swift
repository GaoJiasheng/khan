// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "KhanUI",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "KhanUI", targets: ["KhanUI"])
    ],
    dependencies: [
        .package(path: "../KhanCore")
    ],
    targets: [
        .target(
            name: "KhanUI",
            dependencies: [
                .product(name: "KhanCore", package: "KhanCore")
            ],
            path: "Sources/KhanUI",
            resources: [
                .copy("HeroAnim")
            ]
        )
    ]
)
