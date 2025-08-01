// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "workmanager_apple",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "workmanager_apple",
            targets: ["workmanager_apple"]
        )
    ],
    targets: [
        .target(
            name: "workmanager_apple",
            path: "Sources/workmanager_apple",
            resources: [
                .process("../Resources")
            ]
        )
    ]
)
