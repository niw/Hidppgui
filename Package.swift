// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Hidppgui",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ServiceSupport",
            targets: [
                "ServiceSupport"
            ]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/niw/HIDPP",
            branch: "master"
        )
    ],
    targets: [
        .target(
            name: "ServiceSupport",
            dependencies: [
                .product(name: "HIDPP", package: "HIDPP")
            ]
        )
    ]
)
