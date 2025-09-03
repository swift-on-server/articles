import Hummingbird

@main struct App {
    static func main() async throws {
        // snippet.router
        typealias AppRequestContext = BasicRequestContext
        let router = Router(context: AppRequestContext.self)
        // snippet.end

        // snippet.health
        router.get("/health") { _, _ -> HTTPResponse.Status in
            .ok
        }
        // snippet.end

        // snippet.basic_route
        router.get("/") { _, _ -> String in
            "My app works!"
        }
        // snippet.end

        // snippet.codable_route
        struct MyResponse: ResponseCodable {
            let message: String
        }

        router.get("/message") { _, _ -> MyResponse in
            MyResponse(message: "Hello, world!")
        }
        // snippet.end

        // snippet.run
        let app = Application(router: router)
        try await app.runService()
        // snippet.end
    }
}
