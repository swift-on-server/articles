// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Swift Snippets",
    products: [
        .library(name: "SnippetsExample", targets: ["SnippetsExample"])
    ],
    targets: [
        .target(name: "SnippetsExample")
    ]
)
