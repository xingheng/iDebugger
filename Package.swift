// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
// Version: See .version file for unified versioning across CocoaPods and SPM

import PackageDescription

let package = Package(
    name: "iDebugger",
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "iDebugger",
            targets: ["iDebugger"]
        ),
    ],
    targets: [
        .target(
            name: "iDebugger",
            dependencies: [],
            path: "Sources/iDebugger",
            publicHeadersPath: "."
        ),
    ]
)
