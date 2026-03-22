// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Peak",
    platforms: [
        .macOS(.v13)
    ],
    products: [],
    dependencies: [
        .package(url: "https://github.com/stephencelis/SQLite.swift", from: "0.15.3"),
        .package(url: "https://github.com/argmaxinc/WhisperKit",      from: "0.9.0"),
    ],
    targets: [
        .executableTarget(
            name: "Peak",
            dependencies: [
                .product(name: "SQLite",     package: "SQLite.swift"),
                .product(name: "WhisperKit", package: "WhisperKit"),
            ],
            path: "Peak",
            exclude: [
                "App/Info.plist",
                "App/Peak.entitlements",
            ],
            resources: [
                .process("Assets.xcassets"),
            ]
        )
    ]
)
