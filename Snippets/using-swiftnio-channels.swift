import NIOCore
import NIOPosix

func runServer() async throws {
    // snippet.bootstrap
    // 1.
    let server = try await ServerBootstrap(
        group: NIOSingletons.posixEventLoopGroup
    )
    .bind(  // 2.
        host: "0.0.0.0",  // 3.
        port: 2048  // 4.
    ) { channel in
        // 5.
        channel.eventLoop.makeCompletedFuture {
            // Add any handlers for parsing or serializing messages here
            // We don't need any for this echo example

            // 6.
            try NIOAsyncChannel(
                wrappingChannelSynchronously: channel,
                configuration: NIOAsyncChannel.Configuration(
                    // We'll read the raw bytes from the socket
                    inboundType: ByteBuffer.self,
                    // We'll also write raw bytes to the socket
                    outboundType: ByteBuffer.self
                )
            )
        }
    }
    // snippet.end

    // We create a task group to manage the lifetime of our client connections
    // Each client is handled by its own structured task
    // snippet.acceptClients
    // 1.
    try await withThrowingDiscardingTaskGroup { group in
        // 2.
        try await server.executeThenClose { clients in
            // 3.
            for try await client in clients {
                // 4.
                group.addTask {
                    // 5.
                    do {
                        try await handleClient(client)
                    }
                    catch {
                        // Error while handling the connection.
                        // This needs to be silenced or gracefully handled
                        // as `throw`ing an error here would close the TCP server
                    }
                }
            }
        }
    }
    // snippet.end

    // snippet.handleClient
    func handleClient(
        _ client: NIOAsyncChannel<ByteBuffer, ByteBuffer>
    )
        async throws
    {
        // 1.
        try await client.executeThenClose { inboundMessages, outbound in
            // 2.
            for try await inboundMessage in inboundMessages {
                // 3.
                try await outbound.write(inboundMessage)

                // MARK: A
                return
            }
        }
    }
    // snippet.end
}

try await runServer()
