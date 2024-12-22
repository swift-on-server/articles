import Hummingbird
import HummingbirdWebSocket
import MongoKitten
import NIOCore
import Foundation
import ServiceLifecycle

struct Post: Codable {
    let id: ObjectId
    let author: String
    let content: String
    let createdAt: Date

    init(author: String, content: String) {
        self.id = ObjectId()
        self.author = author
        self.content = content
        self.createdAt = Date()
    }
}

func createPost(author: String, content: String, in db: MongoDatabase) async throws {
    // 1. Create the post
    let post = Post(author: author, content: content)
    
    // 2. Get the posts collection
    let posts = db["posts"]
    
    // 3. Insert the post
    try await posts.insertEncoded(post)
}

// snippet.routes
func setupRoutes(router: Router<BasicRequestContext>, db: MongoDatabase) {
    router.post("/posts") { request, context -> Response in
        struct CreatePostRequest: Codable {
            let author: String
            let content: String
        }
        let post = try await request.decode(as: CreatePostRequest.self, context: context)
        try await createPost(author: post.author, content: post.content, in: db)
        return Response(status: .created)
    }
}
// snippet.end

// snippet.main
@main
struct RealtimeMongoApp {
    static func main() async throws {
        // 1.
        let db = try await MongoDatabase.connect(to: "mongodb://localhost/social_network")
        
        // 2.
        let connectionManager = ConnectionManager(database: db)


        let router = Router(context: BasicRequestContext.self)
        setupRoutes(router: router, db: db)
        
        // 4.
        var app = Application(
            router: router,
            server: .http1WebSocketUpgrade { request, channel, logger in
                return .upgrade([:]) { inbound, outbound, context in
                    try await connectionManager.withRegisteredClient(outbound) {
                        for try await _ in inbound {
                            // Drop any incoming data, we don't need it
                            // But keep the connection open
                        }
                    }
                }
            }
        )

        // 5.
        app.addServices(connectionManager)
        
        // 6.
        try await app.runService()
    }
}
// snippet.end 

// snippet.connection-manager
actor ConnectionManager {
    private let database: MongoDatabase
    private var outboundConnections: [UUID: WebSocketOutboundWriter] = [:]
    private let jsonEncoder = JSONEncoder()
    
    init(database: MongoDatabase) {
        self.database = database
    }
    
    func broadcast(_ data: Data) async {
        guard let text = String(data: data, encoding: .utf8) else {
            return
        }
        
        for connection in outboundConnections.values {
            try? await connection.write(.text(text))
        }
    }

    func withRegisteredClient<T: Sendable>(
        _ client: WebSocketOutboundWriter,
        perform: () async throws -> T
    ) async throws -> T {
        let id = addClient(client)
        defer { removeClient(id: id) }
        return try await perform()
    }
    
    private func addClient(_ ws: WebSocketOutboundWriter) -> UUID {
        let id = UUID()
        outboundConnections[id] = ws
        return id
    }
    
    private func removeClient(id: UUID) {
        outboundConnections[id] = nil
    }
}
// snippet.end

// snippet.watch-changes
extension ConnectionManager: Service {
    func run() async throws {
        // 1.
        let posts = database["posts"]
        
        // 2.
        let changes = try await posts.watch(type: Post.self)
        
        // 3.
        for try await change in changes {
            // 4.
            if change.operationType == .insert, let post = change.fullDocument {
                // 5.
                let jsonData = try jsonEncoder.encode(post)
                // 6.
                await broadcast(jsonData)
            }
        }
    }
}
// snippet.end