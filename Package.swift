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
        .package(url: "https://github.com/hummingbird-project/hummingbird", from: "2.0.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-auth", from: "2.0.2"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-websocket", from: "2.0.0"),
        .package(url: "https://github.com/hummingbird-project/swift-mustache", from: "2.0.0"),
        .package(url: "https://github.com/hummingbird-project/swift-jobs", from: "1.0.0-rc.1"),
        .package(url: "https://github.com/swift-server/async-http-client", from: "1.21.1"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-nio", from: "2.86.0"),
        .package(url: "https://github.com/apple/swift-nio-extras", from: "1.20.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.5.4"),
        .package(url: "https://github.com/apple/swift-http-types", from: "1.0.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle", from: "2.5.0"),
        .package(url: "https://github.com/grpc/grpc-swift-protobuf", exact: "1.3.0"),
        .package(url: "https://github.com/grpc/grpc-swift-nio-transport", exact: "1.2.0"),
        .package(url: "https://github.com/orlandos-nl/MongoKitten", from: "7.0.0"),
        .package(url: "https://github.com/vapor/jwt-kit", from: "5.0.0"),
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
                .product(name: "JWTKit", package: "jwt-kit"),
            ],
            packageAccess: true
        ),
        .target(
            name: "SnippetsExample"
        ),
    ]
)
