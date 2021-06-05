// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Omiros",
    platforms: [.macOS(.v10_14), .iOS(.v13), .tvOS(.v13)],
    products: [
        .library(
            name: "Omiros",
            targets: ["Omiros"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Omiros",
            dependencies: [],
            exclude: ["Info.plist"]),
        .testTarget(
            name: "OmirosTests",
            dependencies: ["Omiros"])
    ]
)
