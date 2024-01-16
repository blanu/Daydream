// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Daydream",
    platforms: [.macOS(.v14)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Daydream",
            targets: ["Daydream"]
        ),
        .executable(
            name: "DaydreamCompiler",
            targets: ["DaydreamCompiler"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/OperatorFoundation/Datable", branch: "main"),
        .package(url: "https://github.com/OperatorFoundation/Gardener", branch: "main"),
        .package(url: "https://github.com/blanu/Swift-BigInt", branch: "main"),
        .package(url: "https://github.com/OperatorFoundation/Text", branch: "main"),
        .package(url: "https://github.com/OperatorFoundation/TextOperators", branch: "main"),
        .package(url: "https://github.com/OperatorFoundation/TransmissionData", branch: "main"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Daydream",
            dependencies: [
                "Datable",
                "Text",
                "TextOperators",
                "TransmissionData",

                .product(name: "BigNumber", package: "Swift-BigInt"),
            ]
        ),
        .executableTarget(
            name: "DaydreamCompiler",
            dependencies: [
                "Daydream",

                "Datable",
                "Gardener",
                "Text",
                "TextOperators",
                "TransmissionData",

                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "BigNumber", package: "Swift-BigInt"),
            ]
        ),
        .testTarget(
            name: "DaydreamTests",
            dependencies: ["DaydreamCompiler"]),
    ],
    swiftLanguageVersions: [.v5]
)
