// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Swift Snippets",
    products: [
        .library(name: "SnippetsExample", targets: ["SnippetsExample"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0"),
    ],
    targets: [
        .target(name: "SnippetsExample"),
    ]
)
