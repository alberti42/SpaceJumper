// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "SpaceJumper",
    platforms: [.macOS(.v15)],
    dependencies: [
        // Software updates. The Makefile embeds Sparkle.framework in the app.
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0"),
    ],
    targets: [
        // Private SkyLight calls: symbol lookup and bridged window-management operations.
        .target(
            name: "SkyLightBridge",
            path: "Sources/SkyLightBridge",
            linkerSettings: [.linkedFramework("CoreGraphics"), .linkedFramework("ColorSync")]
        ),
        // Space model, navigation and the switch itself.
        .target(
            name: "SpaceJumperCore",
            dependencies: ["SkyLightBridge"],
            path: "Sources/SpaceJumperCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // The menu-bar app.
        .executableTarget(
            name: "SpaceJumper",
            dependencies: ["SpaceJumperCore", .product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/SpaceJumper",
            swiftSettings: [.swiftLanguageMode(.v5)],
            // SwiftPM sets no run path for Sparkle.framework. It lies next to the
            // executable in .build/debug, and in Contents/Frameworks of the app.
            linkerSettings: [.unsafeFlags([
                "-Xlinker", "-rpath", "-Xlinker", "@executable_path",
                "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks",
            ])]
        ),
        // Login item embedded in SpaceJumper.app/Contents/Library/LoginItems.
        .executableTarget(
            name: "LoginHelper",
            path: "Sources/LoginHelper",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "SpaceJumperCoreTests",
            dependencies: ["SpaceJumperCore"],
            path: "Tests/SpaceJumperCoreTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
