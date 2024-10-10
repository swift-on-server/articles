# Beginner's Guide to Protocol Buffers and gRPC with Swift

gRPC is a popular open-source framework by Google that enables efficient communication between various systems and services. It leverages "protocol buffers", an efficient binary format, to write API specifications.

If you're interested in building your own gRPC services, this tutorial explores Protocol Buffers and gRPC in Swift!

## What are Protocol Buffers?

[Protocol Buffers](https://protobuf.dev/), also called "protobuf", is an efficient data serialization method developed by Google. Using protobuf consists of three main components:

- The Protobuf language
- The Swift-Protobuf Compiler
- Swift-Protobuf Library

1. The [protobuf language](https://protobuf.dev/programming-guides/proto3/) is used to define your protocol's data structures.
2. These types are then defined in a `.proto` file, which is fed into the protobuf compiler.
3. The output of the Swift compiler consists of one or more Swift files that handle (de)-serialization to- and from protobuf.
4. The protobuf-swift libraries contains the utilities needed by the produces source files.

Because protobuf compilers and libraries exist for many ecosystems, `proto` files are portable to other projects that need to interface together in various different languages.


## The Protocol Buffer Compiler

The protocol buffer compiler (protoc) is a tool that generates source code for data serialization and gRPC communication from `.proto` schema files.

The protocol buffers compiler supports many [languages](https://protobuf.dev/getting-started/), including Swift. To [install](https://grpc.io/docs/protoc-installation/) protoc on your machine, follow the instructions based on your operating system:

```sh
# install on macOS 
brew install protobuf

# install on Linux
apt install -y protobuf-compiler

# manual install, on any operating system
PB_REL="https://github.com/protocolbuffers/protobuf/releases"
curl -LO $PB_REL/download/v25.1/protoc-25.1-linux-x86_64.zip
unzip protoc-25.1-linux-x86_64.zip -d $HOME/.local
export PATH="$PATH:$HOME/.local/bin"
```

The `protoc` command is now ready to use. The next step involves defining the data structure for a sample todo application. This is accomplished by creating a `todo.proto` file, which will outline the models for the application. Below is the complete protobuf definition:

```protobuf
// todo_messages.proto
syntax = "proto3";

// 1.
package todos;

// 2.
message Empty {}

// 3.
message TodoID {
    string todoID = 1;
}

// 4.
message Todo {
    optional string todoID = 1;
    string title = 2;
    bool completed = 3;
}

// 5.
message TodoList {
    repeated Todo todos = 1;
}
```

1. Define a `todos` namespace for this protobuf file.
2. Create the `Empty` message with an empty structure - which contains no data.
3. The `TodoID` message holds a single string field to represent the ID of a specific "Todo" item.
4. A `Todo` message defines a task with an optional `todoID`, a `title`, and a `completed` status represented by a boolean.
5. Finally, the `TodoList` message contains a list of `Todo` items, through a repeated field.


It is possible to generate a Swift data structure from the proto file using the protoc command. Run the following command in the same directory as your proto file to generate the Swift source code:


```sh
protoc --swift_out=./ --grpc-swift_out=./ todo_messages.proto
```

This command will create a todo_messages.pb.swift file, which contains the structs representing the protocol buffer description. 

With the data model in place, the next step is to build a simple gRPC interface that will serve as the foundation for a future gRPC server.

## What is gRPC?

[gRPC](https://grpc.io/) (gRPC Remote Procedure Call) is an open-source framework developed by Google. It enables efficient communication between distributed systems and services, allowing them to collaborate seamlessly.

It is quite similar to the OpenAPI standard, but Protocol Buffers are more efficient, as they use a binary format instead of JSON. 

When using the OpenAPI format, schemas are defined using a JSON or YAML file. In contrast, Protocol Buffers define the schema of data structures using a `.proto` file, which specifies the structure and data types to be serialized.

Below is the protobuf definition for the sample todo service:

```protobuf
// todo.proto
syntax = "proto3";

package todos;

// 1.
import "todo_messages.proto";

// 2. 
service TodoService {
  // 3. 
  rpc FetchTodos (Empty) returns (TodoList) {}
  // 4. 
  rpc CreateTodo (Todo) returns (Todo) {}
  // 5. 
  rpc DeleteTodo (TodoID) returns (Empty) {}
  // 6. 
  rpc CompleteTodo (TodoID) returns (Todo) {}
}
```

1. The `todo_messages.proto` file is imported to reuse its message definitions.
2. The `TodoService` defines the service responsible for managing todo operations.
3. The `FetchTodos` method retrieves a list of todos, taking an empty message as input and returning a `TodoList`.
4. The `CreateTodo` method creates a new todo, taking a `Todo` as input and returning the created `Todo`.
5. The `DeleteTodo` method removes a todo, taking a `TodoID` as input and returning an empty response.
6. The `CompleteTodo` method toggles the completion status of a todo, taking a `TodoID` as input and returning the updated `Todo`.

It’s possible to generate the entire gRPC service protocol from this file using the protoc command. Simply run the following command:

```sh
protoc --swift_out=./ --grpc-swift_out=./ todo.proto
```

This will generate the `todo.grpc.swift` file, which contains the protocols that must be implemented when building the gRPC server. It's also worth mentioning that the `protoc` command generates both client and server-side protocols by default.

The process that we just described is an ahead-of-time (manual) code generation, quite similar what we have for the [Swift OpenAPI generator](https://github.com/apple/swift-openapi-generator/blob/main/Examples/README.md#ahead-of-time-manual-code-generation) tool. 

The generated files depend on two Swift libraries, but these packages also include Swift Package Plugins. By leveraging these plugins, the entire generation process can be integrated into the build pipeline.

Now, let's explore how to use the [Swift Protobuf](https://github.com/apple/swift-protobuf) and the [gRPC Swift](https://github.com/grpc/grpc-swift) libraries to set up a basic server.

## Using Protocol Buffers and gRPC with Swift

First, create a new Swift Package and add both the Protobuf and gRPC libraries as package dependencies. The [Swift Argument Parser](https://github.com/apple/swift-argument-parser) will be included too, and the Protobuf & gRPC plugins will be connected to the executable target. Here’s how to set it up in your `Package.swift` file:


```swift
// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "grpc-example",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.4.0"),
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.28.0"),
        .package(url: "https://github.com/grpc/grpc-swift.git", from: "1.23.0"),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),

                .product(name: "GRPC", package: "grpc-swift"),
                .product(name: "_GRPCCore", package: "grpc-swift"),
            ],
            plugins: [
                .plugin(name: "SwiftProtobufPlugin", package: "swift-protobuf"),
                .plugin(name: "GRPCSwiftPlugin", package: "grpc-swift"),
            ]
        ),
    ]
)
```

The next step is to add the `todo_messages.proto` file into the `Sources/App` directory. Additionally, create a `swift-protobuf-config.json` file to configure the Swift Protobuf plugin:

```json
{
    "invocations": [
        {
            "protoFiles": [
                "todo_messages.proto",
            ],
            "visibility": "internal",
            "server": false,
        },
    ]
}
```

This configuration specifies how the Swift Protobuf plugin will generate code. The `protoFiles` array includes the `todo_messages.proto` file, which will be used as the input for code generation. The `visibility` setting is defined as `internal`, and the `server` flag is set to `false`, indicating that the plugin will generate only the data models without generating any server-side code.

A similar configuration is required for the gRPC Swift plugin. Add the `todo.proto` file to the source directory, and create a `grpc-swift-config.json` file with the following contents:

```json
{
    "invocations": [
        {
            "protoFiles": [
                "todo.proto",
            ],
            "visibility": "internal",
            "server": true,
            "client": false,
            "keepMethodCasing": false,
            "reflectionData": true
        }
    ]
}
```

By using the Swift gRPC plugin, server-side Swift code is generated, and it utilizes the data types produced by the Swift Protobuf plugin.

It's important to note that the Swift Protobuf plugin generates only the data structures. In contrast, the Swift gRPC plugin can generate both the server and client-side interfaces for the whole communication layer. Simply put, Protocol Buffers manage the data encoding and decoding, while gRPC uses Protocol Buffers to enable RPC communication.

One caveat when using Xcode is that the plugins might need to be manually enabled. This can be done in the Report Navigator by clicking the links below the log messages. Another [issue](https://forums.swift.org/t/plugin-doesnt-have-access-to-binary-package-manager-extensible-build-tools-se-0303-and-se-0305/56038/10) is that Xcode may not access external build tools, so linking the protoc command manually may be required using the following command:

```sh
ln -snfv /opt/homebrew/bin/protoc /Applications/Xcode.app/Contents/Developer/usr/bin/protoc
# alternatively, if you're using a beta version
ln -snfv /opt/homebrew/bin/protoc /Applications/Xcode-beta.app/Contents/Developer/usr/bin/protoc
```

After a successful build, the generated data types and interfaces will be available, allowing the implementation of the server-side interface using the gRPC library. Below is an example of a simple actor-based implementation that uses in-memory storage and meets the `TodoService` protocol requirements:

```swift
import GRPC

actor TodoService: Todos_TodoServiceAsyncProvider {
    
    var todos: [Todos_Todo]
    
    init(
        todos: [Todos_Todo] = []
    ) {
        self.todos = todos
    }
    
    func fetchTodos(
        request: Todos_Empty,
        context: GRPC.GRPCAsyncServerCallContext
    ) async throws -> Todos_TodoList {
        var result = Todos_TodoList()
        result.todos += todos
        return result
    }
    
    func createTodo(
        request: Todos_Todo,
        context: GRPC.GRPCAsyncServerCallContext
    ) async throws -> Todos_Todo {
        todos.append(request)
        return request
    }
    
    func deleteTodo(
        request: Todos_TodoID,
        context: GRPC.GRPCAsyncServerCallContext
    ) async throws -> Todos_Empty {
        guard
            let todo = todos.first(where: { $0.todoID == request.todoID })
        else {
            throw GRPCStatus.processingError
        }
        todos = todos.filter { $0.todoID != todo.todoID }
        return .init()
    }
    
    func completeTodo(
        request: Todos_TodoID,
        context: GRPC.GRPCAsyncServerCallContext
    ) async throws -> Todos_Todo {
        guard
            var todo = todos.first(where: { $0.todoID == request.todoID })
        else {
            throw GRPCStatus.processingError
        }
        todo.completed = true
        todos = todos.filter { $0.todoID != request.todoID }
        todos.append(todo)
        return todo
    }
}
```

The snippet above utilizes several types from the gRPC library, such as `GRPCStatus`, and `GRPCAsyncServerCallContext`, which is passed as an argument to each call. Additionally, the functions use the Swift data types generated from the `todo_messages.proto` definition, allowing you to provide the required input and output data.

The final step is to configure the gRPC server. This can be done by using a an `Entrypoint` struct as a main entry point. We'll utilize the Swift Argument Parser library to allow users to specify both the hostname and port when launching the application. 

This setup is based on the v1 gRPC library, which operates with `EventLoopFutures`. However, v2 is already in development and is built on modern Swift concurrency features, utilizing the Service Lifecycle library. As a result, this process will become much simpler once v2 is released.

Below is an example of how to configure the server using the current gRPC release (v1):

```swift
import ArgumentParser
import Logging
import GRPC
import NIO
import GRPCCore

@main
struct Entrypoint: ParsableCommand {
    
    @Option(name: .shortAndLong)
    var hostname: String = "127.0.0.1"
    
    @Option(name: .shortAndLong)
    var port: Int = 1234
    
    func run() throws {
        
        var logger = Logger(label: "grpc-example")
        logger.logLevel = .debug
        
        let group: EventLoopGroup = .singletonMultiThreadedEventLoopGroup

        // 1. 
        let server = Server.insecure(group: group)
            .withServiceProviders(
                [
                    // 2.
                    TodoService(),
                ]
            )
            // 3.
            .bind(to: .host(hostname, port: port))
        
        // 4.
        server.map {
            $0.channel.localAddress
        }.whenSuccess { address in
            logger.debug("gRPC Server started on port \(address!.port!)")
        }
        
        // 5.
        _ = try server.flatMap { $0.onClose }.wait()
    }
}
```

1.	The `Server.insecure(group:)` creates a gRPC server using the specified `EventLoopGroup` for handling requests.
2.	The `withServiceProviders` method registers the `TodoService` instance, which contains the service logic for handling gRPC requests.
3.	The `.bind(to:)` method binds the server to the specified hostname and port, making it ready to accept incoming requests.
4.	The `server.map` retrieves the local address of the server and logs a message indicating that the gRPC server has successfully started on the specified port.
5.	The application waits for the server to close before shutting down, keeping the server running to handle requests.

To test the gRPC server, the [Evans gRPC client](https://github.com/ktr0731/evans) is a great option. Evans is a user-friendly, interactive gRPC client that allows developers to communicate with gRPC servers without needing to write any additional code. It provides a REPL-like interface for interacting with the server’s methods.

Evans is available via the Homebrew package manager, making installation straightforward. Simply run the following command:

```sh
brew tap ktr0731/evans && brew install evans
```

Once installed, you can connect to your gRPC server by specifying the host and port:

```sh
evans repl --host localhost --port 1234 --proto ./todo.proto
```

This will launch Evans in interactive mode, allowing you to call the available RPC methods defined in your .proto files. Evans simplifies testing gRPC servers, making it a valuable tool during development and debugging.

## Summary

That’s all it takes to set up a basic gRPC server using Swift and Protocol Buffers. Many advanced features are available, such as streaming, bidirectional data flow, and generating client-side code. I hope this tutorial has provided a solid foundation for getting started with gRPC servers in Swift using the Swift Protobuf and gRPC libraries.

