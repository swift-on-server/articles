# Beginner's Guide to Protocol Buffers and gRPC with Swift

gRPC is a popular open-source framework by Google that enables efficient communication between various systems and services. It leverages "protocol buffers", an efficient binary format, to write API specifications.

If you're interested in building your own gRPC services, this tutorial explores Protocol Buffers and gRPC in Swift.

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

### The Protobuf language

Protobuf defines structured data using `.proto` schema files, where message types are declared with fields that have unique tags for identification. 

Each field has a type, such as integers, strings, or nested messages, and can be marked as optional or repeated. When compiled, these definitions generate code in various languages, allowing efficient serialization and deserialization of data. 

The language is designed to be compact, fast, and backward-compatible, making it ideal for communication between services or for long-term data storage.

A [VSCode plugin](https://marketplace.visualstudio.com/items?itemName=zxh404.vscode-proto3) is available that provides syntax highlighting and validation features, making it easier to work with `.proto` files.


### The Protocol Buffer Compiler

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

The `protoc` command is now ready for use. This extensible tool allows for the generation of language-specific code through plugins. The second major version of the [gRPC Swift protobuf](https://github.com/grpc/grpc-swift-protobuf/)  library includes a protoc plugin that generates Swift data structures and a gRPC interface, specifically tailored for this version.

You can install the plugin using the following snippet, which will place the `protoc-gen-grpc-swift` binary in your home folder:

```sh
git clone https://github.com/grpc/grpc-swift-protobuf.git
cd grpc-swift-protobuf
swift build -c release
cp "$(swift build --show-bin-path -c release)/protoc-gen-grpc-swift" /Users/{me}/
```

The next step involves defining the data structure for a sample todo application. This is accomplished by creating a `todo.proto` file, which will outline the models for the application. Below is the complete protobuf definition:

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
protoc \
    --plugin=/Users/{me}/protoc-gen-grpc-swift \ 
    --swift_out=./ \
    todo_messages.proto
```

This command will create a `todo_messages.pb.swift` file, which contains the structs representing the protocol buffer description. 

With the data model in place, the next step is to build a simple gRPC interface that will serve as the foundation for a future gRPC server.

## What is gRPC?

[gRPC](https://grpc.io/) (gRPC Remote Procedure Call) is an open-source framework developed by Google. It enables efficient communication between distributed systems and services, allowing them to collaborate seamlessly.

It's used similarly to the OpenAPI standard, but has two key differences:

- gRPC uses protobuf, which is more compact and performant than JSON or Multipart.
- gRPC supports bi-directional streaming as opposed to OpenAPI's request/response model.


Below is the protobuf definition for the todo gRPC service:

```protobuf
// todo_service.proto
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
protoc \
    --plugin=/Users/tib/protoc-gen-grpc-swift \
    --grpc-swift_out=./ \
    todo_service.proto
```

This will generate the `todo_service.grpc.swift` file, which contains the protocols that must be implemented when building the gRPC server. It's also worth mentioning that the `protoc` command generates both client and server-side protocols by default.

The above process uses ahead-of-time (manual) code generation, quite similar what we have for the [Swift OpenAPI generator](https://github.com/apple/swift-openapi-generator/blob/main/Examples/README.md#ahead-of-time-manual-code-generation) tool. 

Now, let's explore how to use the [Swift Protobuf](https://github.com/apple/swift-protobuf) and the [gRPC Swift](https://github.com/grpc/grpc-swift) libraries to set up a basic server.

## Using Protocol Buffers and gRPC with Swift

First, create a new Swift Package and add both the Protobuf and gRPC libraries as package dependencies. The [Swift Argument Parser](https://github.com/apple/swift-argument-parser) will be included too, and the Protobuf & gRPC plugins will be connected to the executable target. Here’s how to set it up in your `Package.swift` file:


```swift
// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "gRPC-example",
    platforms: [
        .macOS(.v15),
    ],
    dependencies: [
        .package(url: "https://github.com/grpc/grpc-swift-protobuf", exact: "1.0.0-alpha.1"),
        .package(url: "https://github.com/grpc/grpc-swift-nio-transport", exact: "1.0.0-alpha.1"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),

                .product(name: "GRPCNIOTransportHTTP2", package: "grpc-swift-nio-transport"),
                .product(name: "GRPCProtobuf", package: "grpc-swift-protobuf"),
            ]
        ),
    ]
)
```

The next step is to add the previously generated Swift files file into the `Sources/App/Generated` directory. Make sure you copy both the `todo_messages.pb.swift` and the `todo_service.grpc.swift` files.

The generated data types and interfaces are now available, allowing the implementation of the server-side interface using the gRPC library. Below is an example of a simple actor-based implementation that uses in-memory storage and meets the `TodoService` protocol requirements:

```swift
import GRPCNIOTransportHTTP2
import GRPCProtobuf

actor TodoService: Todos_TodoService_ServiceProtocol {

    var todos: [Todos_Todo]
    
    init(
        todos: [Todos_Todo] = []
    ) {
        self.todos = todos
    }

    func createTodo(
        request: ServerRequest<Todos_Todo>,
        context: ServerContext
    ) async throws -> ServerResponse<Todos_Todo> {
        todos.append(request.message)
        return .init(message: request.message)
    }
    
    func fetchTodos(
        request: ServerRequest<Todos_Empty>,
        context: ServerContext
    ) async throws -> ServerResponse<Todos_TodoList> {
        var result = Todos_TodoList()
        result.todos = todos
        return .init(message: result)
    }
    
    func completeTodo(
        request: ServerRequest<Todos_TodoID>,
        context: ServerContext
    ) async throws -> ServerResponse<Todos_Todo> {
        guard
            var todo = todos.first(where: { $0.todoID == request.message.todoID })
        else {
            return .init(
                error: RPCError.init(
                    code: .notFound,
                    message: "Todo not found."
                )
            )
        }
        todo.completed = true
        todos = todos.filter { $0.todoID != request.message.todoID }
        todos.append(todo)
        return .init(message: todo)

    }
    
    func deleteTodo(
        request: ServerRequest<Todos_TodoID>,
        context: ServerContext
    ) async throws -> ServerResponse<Todos_Empty> {
        guard
            let todo = todos.first(where: { $0.todoID == request.message.todoID })
        else {
            return .init(
                error: RPCError.init(
                    code: .notFound,
                    message: "Todo not found."
                )
            )
        }
        todos = todos.filter { $0.todoID != todo.todoID }
        return .init(message: .init())
    }
}
```

The snippet above utilizes several types from the gRPC library, such as `ServerRequest`, and `ServerContext`, which is passed as an argument to each call. Additionally, the functions use the Swift data types generated from the `todo_messages.proto` definition, allowing you to provide the required input and output data.

The final step is to configure the gRPC server. This can be done by using a an `Entrypoint` struct as a main entry point. We'll utilize the Swift Argument Parser library to allow users to specify both the hostname and port when launching the application. 

This setup is based on the v2 gRPC library, which supports modern concurrency features, utilizing task groups and the Service Lifecycle library. Below is an example of how to configure the server using the upcoming gRPC release (v2):

```swift
import ArgumentParser
import GRPCNIOTransportHTTP2
import GRPCProtobuf

@main
struct Entrypoint: AsyncParsableCommand {
    
    @Option(name: .shortAndLong)
    var hostname: String = "127.0.0.1"
    
    @Option(name: .shortAndLong)
    var port: Int = 1234
    
    func run() async throws {
        // 1.
        let server = GRPCServer(
            transport: .http2NIOPosix(
                address: .ipv4(host: hostname, port: port),
                config: .defaults(transportSecurity: .plaintext)
            ),
            services: [
                // 2.
                TodoService()
            ]
        )

        // 3.
        try await withThrowingDiscardingTaskGroup { group in
            group.addTask { try await server.serve() }
            // 4.
            if let address = try await server.listeningAddress {
                print("gRPC server listening on \(address)")
            }
        }
    }
}
```

1.	Creates a gRPC server using the specified `http2NIOPosix` transport layer with the provided configuration. 
2.	Add the `TodoService` as a service, which contains the logic for handling gRPC requests.
3.	Start the server asynchronously within a throwing task group.
4.	The server’s listening address is printed if successfully started.


To test the gRPC server, the [Evans gRPC client](https://github.com/ktr0731/evans) is a great option. Evans is a user-friendly, interactive gRPC client that allows developers to communicate with gRPC servers without needing to write any additional code. It provides a REPL-like interface for interacting with the server’s methods.

Evans is available via the Homebrew package manager, making installation straightforward. Simply run the following command:

```sh
brew tap ktr0731/evans && brew install evans
```

Once installed, you can connect to your gRPC server by specifying the host and port:

```sh
evans repl --host localhost --port 1234 --proto ./todo_service.proto
```

This will launch Evans in interactive mode, allowing you to call the available RPC methods defined in your `.proto` files. Evans simplifies testing gRPC servers, making it a valuable tool during development and debugging.

## Summary

That’s all it takes to set up a basic gRPC server using Swift and Protocol Buffers. Many advanced features are available, such as streaming, bidirectional data flow, and generating client-side code. I hope this tutorial has provided a solid foundation for getting started with gRPC servers in Swift using the Swift Protobuf and gRPC libraries.

