// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "workmanager_apple",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        // The library name uses a hyphen because Flutter requires SwiftPM product
        // names to not contain underscores. The target keeps the underscore.
        .library(
            name: "workmanager-apple",
            targets: ["workmanager_apple"]
        )
    ],
    targets: [
        .target(
            name: "workmanager_apple",
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
