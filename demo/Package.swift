let package = Package(
    name: "GnostrSDKDemo",
    dependencies: [
        .package(path: "../")
    ],
    targets: [
        .target(
            name: "GnostrSDKDemo",
            dependencies: ["GnostrSDK"])
    ]
)
