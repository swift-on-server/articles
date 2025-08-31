import HTTPTypes
// snippet.imports
import NIOCore
import NIOHTTP1
import NIOHTTPTypes
import NIOHTTPTypesHTTP1
import NIOPosix

// snippet.end

// snippet.partial
enum HTTPPartialResponse {
    case none
    case receiving(HTTPResponse, ByteBuffer)
}
// snippet.end

// snippet.error
enum HTTPClientError: Error {
    case malformedResponse, unexpectedEndOfStream
}
// snippet.end

// snippet.client
struct HTTPClient {
    let host: String
    let httpClientBootstrap: ClientBootstrap

    init(host: String) {
        // snippet.bootstrap
        // 1
        let httpClientBootstrap = ClientBootstrap(
            group: NIOSingletons.posixEventLoopGroup
        )
        // 2
        .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
        // 3
        .channelInitializer { channel in
            // 4
            channel.eventLoop.makeCompletedFuture {
                try channel.pipeline.syncOperations.addHTTPClientHandlers()
                try channel.pipeline.syncOperations.addHandler(
                    HTTP1ToHTTPClientCodec()
                )
            }
        }
        // snippet.end

        self.host = host
        self.httpClientBootstrap = httpClientBootstrap
    }

    func request(
        _ path: String,
        method: HTTPRequest.Method = .get,
        headers: HTTPFields = [:]
    ) async throws -> (HTTPResponse, ByteBuffer) {
        // 1
        let clientChannel =
            try await httpClientBootstrap.connect(
                host: host,
                port: 80
            )
            .flatMapThrowing { channel in
                // 2
                try NIOAsyncChannel(
                    wrappingChannelSynchronously: channel,
                    configuration: NIOAsyncChannel.Configuration(
                        inboundType: HTTPResponsePart.self,  // 3
                        outboundType: HTTPRequestPart.self  // 4
                    )
                )
            }
            .get()  // 5
        // snippet.end

        // snippet.executeThenClose
        // 1
        return try await clientChannel.executeThenClose { inbound, outbound in
            // 2
            try await outbound.write(
                .head(
                    HTTPRequest(
                        method: method,
                        scheme: "http",
                        authority: host,
                        path: path,
                        headerFields: headers
                    )
                )
            )
            try await outbound.write(.end(nil))
            // snippet.end

            // snippet.httpLogic
            var partialResponse = HTTPPartialResponse.none

            // 1
            for try await part in inbound {
                // 2
                switch part {
                case .head(let head):
                    guard case .none = partialResponse else {
                        throw HTTPClientError.malformedResponse
                    }

                    let buffer = clientChannel.channel.allocator.buffer(
                        capacity: 0
                    )
                    partialResponse = .receiving(head, buffer)
                case .body(let buffer):
                    guard
                        case .receiving(let head, var existingBuffer) =
                            partialResponse
                    else {
                        throw HTTPClientError.malformedResponse
                    }

                    existingBuffer.writeImmutableBuffer(buffer)
                    partialResponse = .receiving(head, existingBuffer)
                case .end:
                    guard
                        case .receiving(let head, let buffer) = partialResponse
                    else {
                        throw HTTPClientError.malformedResponse
                    }

                    return (head, buffer)
                }
            }

            // 3
            throw HTTPClientError.unexpectedEndOfStream
            // snippet.end
        }
    }
}

// snippet.usage
let client = HTTPClient(host: "example.com")
let (response, body) = try await client.request("/")
print(response)
print(body.getString(at: 0, length: body.readableBytes)!)
// snippet.end

extension HTTPPart: @unchecked Sendable {}
