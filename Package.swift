// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package: Any = Package(
        name: "sp2battlebot",
        platforms: [
            .macOS(.v10_12),
        ],
        dependencies: [
            // Dependencies declare other packages that this package depends on.
            // .package(url: /* package url */, from: "1.0.0"),
            .package(url: "https://github.com/nikstar/Telegrammer.git", .branch("foundationnetworking")),
            .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.12.0"),
        ],
        targets: [
            // Targets are the basic building blocks of a package. A target can define a module or a test suite.
            // Targets can depend on other targets in this package, and on products in packages which this package depends on.
            .target(
                    name: "sp2battlebot",
                    dependencies: ["Telegrammer", "SQLite"]),
            .testTarget(
                    name: "sp2battlebotTests",
                    dependencies: ["sp2battlebot"]),
        ]
)
