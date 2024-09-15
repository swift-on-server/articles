# Enabling HTTP/2 in Hummingbird

[Hummingbird](https://hummingbird.codes) features a flexible architecture that allows swapping various components in and out. This flexibility extends to the networking layer, where you can easily swap out the default HTTP/1 networking code for one supporting HTTP/2.

## Package Manifest

As part of your code, you'll have a target that depends on Hummingbird.

```swift
.executableTarget(
    name: "App",
    dependencies: [
        .product(name: "Hummingbird", package: "hummingbird"),
        ...
    ]
),
```

Because Hummingbird aims to only compile what you need, Hummingbird doesn't enable HTTP/2 support by default. In order to use HTTP/2, you'll first need to depend on the `HummingbirdHTTP2` module within the Hummingbird package.

Add the following product to your target's dependencies:

```swift
.product(name: "HummingbirdHTTP2", package: "hummingbird"),
```

## Enabling HTTP/2

First, in your application, you'll need to import the relevant dependencies:

@Snippet(path: "site/Snippets/hummingbird-2-http-2", slice: "imports")

HTTP/2 can only be enabled if your server already supports TLS. In order to support TLS, you'll need to create a ``TLSConfiguration`` from ``NIOSSL``.

You'll need to obtain this certificate through a certificate authority (CA) or generate a self-signed certificate.

Then, using this certificate, you can create a ``TLSConfiguration`` object that Hummingbird can use to serve HTTP/1.1 and HTTP/2 traffic.

@Snippet(path: "site/Snippets/hummingbird-2-http-2", slice: "tls")

Finally, when creating your server, you can pass this configuration to the server's initializer.

@Snippet(path: "site/Snippets/hummingbird-2-http-2", slice: "application")

With this configuration, your server will now support HTTP/2 traffic.

## Conclusion

Enabling HTTP/2 in Hummingbird is straightforward. By adding the `HummingbirdHTTP2` module to your target's dependencies and loading your server's TLS certificate, you can easily enable HTTP/2 support in your Hummingbird application.

The pluggable architecture of Hummingbird makes it easy to swap out components, such as the networking layer, to support new features like HTTP/2.