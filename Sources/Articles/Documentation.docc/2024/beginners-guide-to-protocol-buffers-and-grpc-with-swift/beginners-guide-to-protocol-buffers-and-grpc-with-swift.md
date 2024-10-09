# Beginner's Guide to Protocol Buffers and gRPC with Swift

This tutorial will explore Protocol Buffers and the gRPC communication service. For those unfamiliar with these technologies, this guide provides an excellent introduction to using them with Swift.

## What Are Protocol Buffers?

Protocol Buffers [protobuf](https://protobuf.dev/) is a data serialization method developed by Google. It is particularly useful for enabling programs to communicate over a network or for efficiently storing structured data.

Protocol Buffers are extensively used across various applications, such as network communication, data storage, and configuration management. They offer a language-neutral, platform-neutral, and extensible approach to serializing structured data.

## What is gRPC?

[gRPC](https://grpc.io/) (gRPC Remote Procedure Call) is an open-source framework developed by Google. It enables efficient communication between distributed systems and services, allowing them to collaborate seamlessly.

It is quite similar to the OpenAPI standard, but Protocol Buffers are more efficient, as they use a binary format instead of JSON. 

When using the OpenAPI format, schemas are defined using a JSON or YAML file. In contrast, Protocol Buffers define the schema of data structures using a `.proto` file, which specifies the structure and data types to be serialized.


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
message TodoList {
    repeated Todo todos = 1;
}

// 4.
message TodoID {
    string todoID = 1;
}

// 5.
message Todo {
    optional string todoID = 1;
    string title = 2;
    bool completed = 3;
}
```

1. The package `todos` defines the namespace for this protobuf file.
2. The `Empty` message is an empty structure, often used for simple requests or responses without data.
3. The `TodoList` message contains a list of `Todo` items, marked as a repeated field.
4. The `TodoID` message holds a single string field to represent the ID of a specific Todo item.
5. The `Todo` message defines a task with an optional `todoID`, a `title`, and a `completed` status represented by a boolean.


It is possible to generate a Swift data structure from the proto file using the protoc command. Run the following command in the same directory as your proto file to generate the Swift source code:


```sh
protoc --swift_out=./ --grpc-swift_out=./ todo_messages.proto
```

This command will create a todo_messages.pb.swift file, which contains the structs representing the protocol buffer description. 

With the data model in place, the next step is to build a simple gRPC interface that will serve as the foundation for a future gRPC server. Below is the protobuf definition for the sample todo service:


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

In this case, we'd like to generate server-side Swift code.

TODO: enable plugin when using from Xcode...

https://forums.swift.org/t/plugin-doesnt-have-access-to-binary-package-manager-extensible-build-tools-se-0303-and-se-0305/56038/10


```sh
ln -snfv /opt/homebrew/bin/protoc /Applications/Xcode-beta.app/Contents/Developer/usr/bin/protoc
```


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

        let server = Server.insecure(group: group)
            .withServiceProviders(
                [
                    TodoService(),
                ]
            )
            .bind(to: .host(hostname, port: port))
        
        server.map {
            $0.channel.localAddress
        }.whenSuccess { address in
            logger.debug("gRPC Server started on port \(address!.port!)")
        }
        
        _ = try server.flatMap { $0.onClose }.wait()
    }
}
```


```sh
brew tap ktr0731/evans && brew install evans
evans repl --host localhost --port 1234 --proto ./todo.proto
```


























