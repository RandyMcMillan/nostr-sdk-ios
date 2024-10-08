// swift-tools-version: 5.7.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "libp2p-nostr",
    platforms: [.macOS(.v12), .iOS(.v15)],
    products: [
        .library(
            name: "App",
            targets: ["App"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/swift-libp2p/swift-libp2p", .upToNextMinor(from: "0.1.0")),
        .package(url: "https://github.com/swift-libp2p/swift-libp2p-noise", .upToNextMinor(from: "0.1.0")),
        .package(url: "https://github.com/swift-libp2p/swift-libp2p-mplex", .upToNextMinor(from: "0.1.0")),
        .package(url: "https://github.com/realm/SwiftLint.git", .upToNextMinor(from: "0.52.2")),
        .package(url: "https://github.com/apple/swift-docc-plugin.git", from: "1.0.0"),
        //.package(url: "https://github.com/GigaBitcoin/secp256k1.swift", from: "0.12.2"),
        .package(url: "https://github.com/BoilerTalk/secp256k1.swift", from: "0.1.6"),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", .upToNextMajor(from: "1.7.0")),
        //.package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", .upToNextMajor(from: "1.8.1")),
        .package(url: "https://github.com/apple/swift-collections.git", .upToNextMajor(from: "1.1.2"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "App",
            dependencies: [
                .product(name: "LibP2P", package: "swift-libp2p"),
                .product(name: "LibP2PNoise", package: "swift-libp2p-noise"),
                .product(name: "LibP2PMPLEX", package: "swift-libp2p-mplex"),
            ],
            plugins: [.plugin(name: "SwiftLintPlugin", package: "SwiftLint")]),
        .executableTarget(
            name: "Run",
            dependencies: [
            .target(name: "App"),
            .product(name: "secp256k1", package: "secp256k1.swift"),
                //.product(name: "Clibsodium", package: "swift-sodium"),
                "CryptoSwift",
                .product(name: "OrderedCollections", package: "swift-collections")
            ]
            ),
        .testTarget(
            name: "AppTests",
            dependencies: [
                .target(name: "App"),
                //.target(name: "NostrSDK"),
            ],
            resources: [.copy("Fixtures")],
            plugins: [.plugin(name: "SwiftLintPlugin", package: "SwiftLint")]
            ),
    ]
)
