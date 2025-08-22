## Working with the SwiftNIO File System: Practical Examples

SwiftNIO is a powerful networking framework, but it also provides a modern, async-friendly file system API. The NIO file system module lets you create, read, write, and manage files and directories in a non-blocking way. 

In this article, we’ll walk through common and interesting use-cases, with clear, concise Swift examples.

## Setup NIOFileSystem

NIOFileSystem. This provides async APIs for interacting with the file system. Fist you have to add swift-nio as a package dependency to your target.


```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Example",
    platforms: [
        .macOS(.v15),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio", from: "2.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "Example",
            dependencies: [
                .product(name: "_NIOFileSystem", package: "swift-nio"),
            ]
        ),
    ]
)
```

The _NIOFileSystem module uses an underscore in its name to show that it is not a stable, public API yet. This means the module is still under active development by the SwiftNIO team, and its features or interfaces might change in future releases. 

Developers should be careful when using it in production, as updates could introduce breaking changes. The team is working to improve and finalize the file system module, so it's best to keep an eye on updates for more stable releases in the future.


## Creating files

This snippet demonstrate how to create a file. In this case we save the file to a temporary file path, then write a simple string to it. Here’s how:

```swift
import _NIOFileSystem

// 1.
let fs = FileSystem.shared
// 2.
var temporaryPath = try await fs.temporaryDirectory
let path = temporaryPath.appending("hello.txt")

let contents = "Hello, NIO File System!"
// 3.
let bytesWritten = try await contents.write(
    toFileAt: path,
    options: .modifyFile(createIfNecessary: true)
)

print("Bytes written: \(bytesWritten)")
```

1. Access the shared file system instance using `FileSystem.shared`. This instance provides async methods for file operations.
2. It asynchronously retrieves the system’s temporary directory.
3. The string is written to the file at the specified path using the async `write` method. The `.modifyFile(createIfNecessary: true)` option ensures the file is created if it doesn’t exist. The number of bytes written is returned and printed.

## File information

The file system API lets you check for a file’s existence and get its info. This method returns nil if the file does not exists:

```swift
if let info = try await fs.info(forFileAt: path) {
    print("Type: \(info.type), Size: \(info.size)")
} 
```

The info contains type, size, last modification info, permission and group and even more system level file information. You can use the type property to check if the file was a regular file or a directory or a symlink. The FileType struct has even more cases, like sockets.

## Listing Directories

The most simple way to list and iterate over a directory is by using an directory handle and the listContents function. The listContents method returns a DirectoryEntries type, which is an AsyncSequence so you can iterate over the elements using a for loop:

```swift
let homePath = FilePath("/path/to/dir")

let info = try await fs.info(forFileAt: homePath)
if let info, info.type == .directory {
    try await fs.withDirectoryHandle(atPath: homePath) { dir in
        for try await entry in dir.listContents() {
            print("Found: \(entry.name)")
        }
    }
}
else {
    print("not exists")
}
```

It's also possible to list the contents recursively and put a filter on entry types by using a where clause in the iteration:

```swift

try await fs.withDirectoryHandle(atPath: homePath) { dir in
    let entries = dir.listContents()

    for 
        try await entry in entries 
    where 
        entry.type != .directory 
    {
        print("Found: \(entry.name)")
    }
}
```

In this example we list directory contents recursively and print only the files.

Another common use-case is to list non-hidden directories only, this is possible by putting a where clause on the name string:

```swift
try await fs.withDirectoryHandle(atPath: homePath) { dir in
    let entries = dir.listContents()

    for
        try await entry in entries
    where
        entry.type == .directory &&
        !entry.name.string.hasPrefix(".")
    {
        print("Found: \(entry.name)")
    }
}
```

Batch iterate, when there are too many items:

```swift
try await fs.withDirectoryHandle(atPath: homePath) { dir in
    let batches = dir.listContents(recursive: true).batched()

    for try await batch in batches  {
        for entry in batch {
            print("Found: \(entry.name)")
        }
    }
}
```

Don't forget to check if the file exists and it's a directory before you start using the handle.

## Writing and Reading Data

You can write data from strings, arrays, or even async sequences. To read, you can load the whole file or just a chunk.

Write a string and read it back:

```swift
try await "Some text".write(
    toFileAt: path,
    options: .modifyFile(createIfNecessary: true)
)
let text = try await String(
    contentsOf: path,
    maximumSizeAllowed: .bytes(1024)
)
print("Read text: \(text)")
```

Write and read a byte array:

```swift
let data: [UInt8] = [1, 2, 3, 4, 5]
try await data.write(
    toFileAt: path,
    options: .modifyFile(createIfNecessary: true)
)
let readData = try await Array(
    contentsOf: path,
    maximumSizeAllowed: .bytes(1024)
)
print("Read bytes: \(readData)")
```

## Buffered Reading and Writing

Buffered readers and writers help with large files or performance-sensitive tasks.

Buffered Writer Example:

```swift
try await fs.withFileHandle(
    forReadingAndWritingAt: path,
    options: .newFile(replaceExisting: true)
) { file in
    var writer = file.bufferedWriter(capacity: .bytes(4096))
    try await writer.write(contentsOf: repeatElement(42, count: 1000))
    try await writer.flush()
}
```

Buffered Reader Example:

```swift
try await fs.withFileHandle(forReadingAt: path) { file in
    var reader = file.bufferedReader(capacity: .bytes(4096))
    let bytes = try await reader.read(.bytes(1000))
    print("Buffered read: \(bytes.readableBytes) bytes")
}
```

## Handling Symbolic Links

You can create and inspect symbolic links:

```swift
let linkPath = try await fs.temporaryDirectory.appending("link.lnk")
try await fs.createSymbolicLink(at: linkPath, withDestination: path)
let destination = try await fs.destinationOfSymbolicLink(at: linkPath)
print("Symlink points to: \(destination)")
```

## Copying and Removing Files

Copy files or directories, and clean up when finished:

```swift
let copyPath = try await fs.temporaryDirectory.appending("copy.txt")
try await fs.copyItem(at: path, to: copyPath)
print("File copied to: \(copyPath)")

let removed = try await fs.removeOneItem(at: copyPath)
print("Items removed: \(removed)")
```

## Advanced: Async Sequences for Streaming Data

You can write data from an ⁠AsyncStream⁠ for efficient streaming:

```swift
let stream = AsyncStream(UInt8.self) { continuation in
    for byte in 0..<64 { continuation.yield(byte) }
    continuation.finish()
}
let bytesWritten = try await stream.write(toFileAt: path)
print("Streamed bytes written: \(bytesWritten)")
```

## Summary

The SwiftNIO file system API is flexible and modern. It supports async/await, handles errors clearly, and works efficiently with both small and very large files. Whether you’re building a server, a tool, or just need fast file I/O, these patterns will help you get started and go further.

