import NIOCore
import NIOPosix

// snippet.bootstrap
// 1.
let server = try await DatagramBootstrap(group: NIOSingletons.posixEventLoopGroup)
    // 2..
    .bind(host: "0.0.0.0", port: 2048)
    .flatMapThrowing { channel in
        return try NIOAsyncChannel(
            wrappingChannelSynchronously: channel,
            configuration: NIOAsyncChannel.Configuration(
                // 4.
                inboundType: AddressedEnvelope<ByteBuffer>.self,
                outboundType: AddressedEnvelope<ByteBuffer>.self
            )
        )
    }
    .get()
// snippet.end

// snippet.packets
try await server.executeThenClose { inbound, outbound in
    for try await var packet in inbound {
        // 1.
        guard let string = packet.data.readString(length: packet.data.readableBytes) else {
            continue
        }

        // 2.
        let response = ByteBuffer(string: String(string.reversed()))

        // 3.
        try await outbound.write(AddressedEnvelope(remoteAddress: packet.remoteAddress, data: response))
    }
}
// snippet.end
