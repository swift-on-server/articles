// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "swiftonserver-articles",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(name: "Articles", targets: ["Articles"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-auth.git", from: "2.0.2"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-websocket.git", from: "2.0.0"),
        .package(url: "https://github.com/hummingbird-project/swift-mustache.git", from: "2.0.0-beta.3"),
        .package(url: "https://github.com/hummingbird-project/swift-jobs.git", from: "1.0.0-beta.6"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.21.1"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
        .package(url: "https://github.com/apple/swift-nio-extras.git", from: "1.20.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.4"),
        .package(url: "https://github.com/apple/swift-http-types.git", from: "1.0.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.5.0"),
        .package(url: "https://github.com/grpc/grpc-swift-protobuf", exact: "1.0.0-alpha.1"),
        .package(url: "https://github.com/grpc/grpc-swift-nio-transport", exact: "1.0.0-alpha.1"),
        .package(url: "https://github.com/orlandos-nl/MongoKitten.git", from: "7.0.0"),
    ],
    targets: [
        .target(
            name: "Articles",
            dependencies: [
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdRouter", package: "hummingbird"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Jobs", package: "swift-jobs"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
                .product(name: "HummingbirdAuth", package: "hummingbird-auth"),
                .product(name: "HummingbirdWebSocket", package: "hummingbird-websocket"),
                .product(name: "HummingbirdWSCompression", package: "hummingbird-websocket"),
                .product(name: "Mustache", package: "swift-mustache"),
                .product(name: "GRPCNIOTransportHTTP2", package: "grpc-swift-nio-transport"),
                .product(name: "GRPCProtobuf", package: "grpc-swift-protobuf"),
                .product(name: "NIOHTTPTypes", package: "swift-nio-extras"),
                .product(name: "NIOHTTPTypesHTTP1", package: "swift-nio-extras"),
                .product(name: "NIOExtras", package: "swift-nio-extras"),
                .product(name: "MongoKitten", package: "MongoKitten"),
            ],
            packageAccess: true
        ),
        .target(
            name: "SnippetsExample"
        ),
    ]
)
