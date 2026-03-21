// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Peak",
    platforms: [
        .macOS(.v13)
    ],
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
                // Not Swift source — handled by the build script
                "App/Info.plist",
                "App/Peak.entitlements",
            ],
            resources: [
                // actool compiles this at build time on Apple platforms
                .process("Assets.xcassets"),
            ],
            swiftSettings: [
                // Use Swift 5 language mode so the existing codebase compiles
                // without Swift 6's strict concurrency enforcement.
                .swiftLanguageMode(.v5),
            ]
        )
    ]
)
