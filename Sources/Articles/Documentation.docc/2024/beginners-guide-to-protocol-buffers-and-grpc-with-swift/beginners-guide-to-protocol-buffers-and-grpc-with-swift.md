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

The [protocol buffer compiler](https://grpc.io/docs/protoc-installation/), protoc, is used to compile `.proto` files, which contain service and message definitions. 

```sh
# install on Linux
apt install -y protobuf-compiler

# install on macOS 
brew install protobuf

# manual install, for any operating system
PB_REL="https://github.com/protocolbuffers/protobuf/releases"
curl -LO $PB_REL/download/v25.1/protoc-25.1-linux-x86_64.zip
unzip protoc-25.1-linux-x86_64.zip -d $HOME/.local
export PATH="$PATH:$HOME/.local/bin"
```

For example, a data structure definition in a proto file could be written as follows:

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

It is possible to generate a Swift data structure from the proto file using the official [Swift Protobuf](https://github.com/apple/swift-protobuf) library.



```sh
protoc --swift_out=./ --grpc-swift_out=./ todo_messages.proto
```


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


```sh
protoc --swift_out=./ --grpc-swift_out=./ todo.proto
```



## Using Protocol Buffers and gRPC with Swift

The package includes a Swift Package Manager plugin, which will be used to generate the Swift files. The plugin relies on the protobuf generator, so the first step is to install it using the Homebrew package manager:


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


swift-protobuf-config.json

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

grpc-swift-config.json

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

enable plugin when using from Xcode...

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


























