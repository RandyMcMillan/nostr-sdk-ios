// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "NostrSDKDemo",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
    ],
    products: [
        .executable(
            name: "NostrSDKDemo",
            targets: ["NostrSDKDemo"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/nostr-sdk/nostr-sdk-ios", .upToNextMajor(from: "0.2.0"))
    ],
    targets: [
        .executableTarget(
            name: "NostrSDKDemo",
            dependencies: [
                .product(name: "NostrSDK", package: "nostr-sdk-ios")
            ]
        )
    ]
)

