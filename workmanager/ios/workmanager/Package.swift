// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "workmanager",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "workmanager", targets: ["workmanager"])
    ],
    dependencies: [
        .package(url: "https://github.com/flutter/engine", from: "0.0.0")
    ],
    targets: [
        .target(
            name: "workmanager",
            dependencies: [
                .product(name: "Flutter", package: "engine")
            ],
            resources: [
                .process("Resources")
            ]
        )
    ]
)