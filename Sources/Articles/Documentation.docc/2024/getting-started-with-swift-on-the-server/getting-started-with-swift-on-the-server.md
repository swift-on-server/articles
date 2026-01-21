# Getting Started with Swift on the Server

Swift is a powerful general-purpose cross-platform programming language by Apple. While it's most commonly associated with iOS and macOS development, the Swift ecosystem is open-source, alive and thriving on the server!

### Why Swift?

Swift is a modern, statically-typed language that's designed to be secure, fast and expressive. Thanks to features such as type inference and labeled parameters, Swift code reads like plain English.

Swift is also designed to be easy to pick up, with a syntax that's concise and expressive. However, as you delve deeper into the language, you'll find that Swift is just as powerful and performant as other languages like C++ and Rust.

This concept, claled "progressive disclosure", is one of the reasons why Swift is so popular. You can utilise high-level features, just like other popular languages. However, when you need to drop down to a lower level, Swift _also_ provides the tools to do so.

In addition to the above, Swift has modern features such as Structured Concurrency, a paradigm that enabled structured programming in an async world. Read more about that here: <doc:getting-started-with-structured-concurrency-in-swift>.

Finally, similarly to Rust, Swift is designed to prevent many types of common programming mistakes. Static type checking, memory safety and race condition checking are all built into the language. This makes Swift a great choice for building secure, reliable and performant applications.

### Swift on the Server

Server-Side Swift is a mature ecosytem that has been around since late 2015. Since then, it's grown to support an impressive array of frameworks, libraries and tools. A remarkable property of Swift on the Server is that _very_ few libraries use C bindings.

This translates into code that's easy to contribute to, while also being secure and performant. More importantly, it has resulted in libraries that integrate seamlessly with one another.

The ecosystem is governed by the [Swift Server WorkGroup](https://swift.org/server/) (SSWG), a group of developers and companies that are dedicated to upholding and improving Swift's excellent server-side capabilities.

While Apple has a stake in the workgroup, uses it for Private Compute cloud, and is actively contributes a lot, it is by no means the only contributor.

## Where to Start

If you're new to Swift on the Server, you might be wondering where to start.

The first thing you'll need to do is install Swift on your machine. You can do this by downloading the latest version of Swift from the [Swift website](https://swift.org/download/).

From there, you can use various editors to write your Swift code. [Xcode](https://developer.apple.com/xcode/) is the most popular choice on macOS, but you can also use [Visual Studio Code](https://www.swift.org/documentation/articles/getting-started-with-vscode-swift.html), or any other editor that supports a language server.

## Frameworks

Once you have Swift installed, you can start exploring the various frameworks available for building server-side applications. The two major ones are [Hummingbird](https://hummingbird.codes) and [Vapor](https://vapor.codes).

Both are mature, feature-rich frameworks that provide a wide range of tools for building web applications. They also have active communities that are always willing to help out with any questions you might have. Finally, most libraries are compatible with both frameworks, so you can easily switch between them if you need to.

Vapor 4 is an older framework, and has a "batteries-included" approach. It comes with a lot of features out of the box, such as authentication, database support, and templating. This makes Vapor very simple to set up.

Hummingbird 2 is the newer framework, adopting the latest ecosystem tools, and features a more modular approach. This makes Hummingbird more flexible and lightweight. In contrast to Vapor, the modular approach means that you only include the features you need, which can result in a smaller binary size, but requires more setup.

## Creating a Project

Once you've chosen your framework, you can begin a new project. Both Vapor and Hummingbird have templates to get you started:

1. <doc:getting-started-with-hummingbird>
2. [Getting Started with Vapor 4](https://vapor.codes)

Once you've created your project setup, you can start building your application. Both frameworks have excellent documentation that will guide you through the process of building a web application.

Alongside a web framework, you'll quickly find that you need to use other libraries to build your application. This commonly includes a database, observability and authentication among others.

Swift Package Manager (SwiftPM) is the way to manage dependencies in Swift, and is built into the toolchain. 

Read more about SwiftPM here: <doc:getting-started-with-swift-package-manager>

## Deploying Backends

Once you've built your application, you'll need to deploy it to a server. There are many different ways to do this, depending on your requirements.

A backend should be hosted on a system that is always connected to the internet. Depending on your project structure and needs, you can either build your backend using _cloud functions_ or as a continuously running binary.

### Cloud Functions

Cloud functions are small pieces of code that are executed in response to an event. They are a great way to build small, stateless services that can be easily scaled up or down.

The advantage of cloud functions is that you only pay for the time your code is running, which can be much cheaper than running a server 24/7. Especially for projects with a relatively low amount of traffic, cloud functions can be a great way to save money.

Popular cloud providers such as AWS, Google Cloud and Azure all provide cloud functions as a service. You can write your Swift code and deploy it to these services using their respective SDKs.

While Vapor doesn't support cloud functions directly, Hummingbird 2's architecture allows it to be easily adapted to run as a cloud function. The cloud functions that Hummingbird officially supports are [AWS Lambda](https://github.com/hummingbird-project/hummingbird-lambda).

Learn more about Lambda here: <doc:getting-started-with-hummingbird-lambda>

### Running Binaries

While cloud functions can be cost effective at small scale, they can sometimes be more expensive if volume is high. This is because cloud functions are billed per invocation, rather than the consumed resources.

Since Server-Side Swift applications are lightweight, a single binary can handle a large amount of traffic. This makes running a continuously running binary a good choice for high-traffic applications.

Popular cloud providers such as AWS, Google Cloud and Azure all provide services that allow you to run a binary on their infrastructure. You can build your Swift binary and deploy it to these services using their respective SDKs.

Finally, you can also deploy your Swift application to a VPS or dedicated server. This gives you full control over the environment, and tends to be cheaper to run but also requires you to manage the server yourself.

Read more about hosting here: <doc:how-to-deploy-cloud-apps>

## Conclusion

Swift is a powerful language that's just as capable on the server as it is on iOS and macOS. With a mature ecosystem, excellent frameworks and a growing community, Swift is a great choice for building server-side applications. The community is always willing to help out, so don't hesitate to ask questions if you get stuck.