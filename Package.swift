// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "site",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "site", targets: ["site"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0-rc.3"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-websocket.git", from: "2.0.0-beta.5"),
        .package(url: "https://github.com/hummingbird-project/swift-mustache", from: "2.0.0-beta.3"),
        .package(url: "https://github.com/swift-server/async-http-client", from: "1.21.1"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.4.0"),
        .package(url: "https://github.com/apple/swift-nio", from: "2.65.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.5.4"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle", from: "2.5.0"),
    ],
    targets: [
        .target(
            name: "site",
            dependencies: [
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdRouter", package: "hummingbird"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
                .product(name: "HummingbirdWebSocket", package: "hummingbird-websocket"),
                .product(name: "HummingbirdWSCompression", package: "hummingbird-websocket"),
            ],
            packageAccess: true
        )
    ]
)
