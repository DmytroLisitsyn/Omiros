// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Omiros",
    platforms: [.macOS(.v10_15), .iOS(.v13), .watchOS(.v6), .tvOS(.v13)],
    products: [
        .library(name: "Omiros", targets: ["Omiros"])
    ],
    dependencies: [],
    targets: [
        .target(name: "Omiros", dependencies: []),
        .testTarget(name: "OmirosTests", dependencies: ["Omiros"])
    ]
)
