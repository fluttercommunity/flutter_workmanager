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
        // No explicit Flutter dependencies needed - handled by Flutter's SPM integration
    ],
    targets: [
        .target(
            name: "workmanager",
            dependencies: [
                // Flutter framework will be automatically available
            ],
            resources: [
                .process("Resources")
            ]
        )
    ]
)