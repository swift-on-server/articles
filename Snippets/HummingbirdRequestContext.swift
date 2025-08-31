import Foundation
import Hummingbird

do {
    // snippet.custom_request_context
    struct CustomContext: RequestContext {
        var coreContext: CoreRequestContextStorage

        init(source: ApplicationRequestContextSource) {
            self.coreContext = .init(source: source)
        }
    }
    // snippet.end

    // snippet.router
    let router = Router(context: CustomContext.self)
    // snippet.end
    _ = router
}

struct User: Identifiable, Codable {
    var id: UUID
}

// snippet.custom_request_context
struct CustomContext: RequestContext {
    var coreContext: CoreRequestContextStorage
    var token: String?

    init(source: ApplicationRequestContextSource) {
        self.coreContext = .init(source: source)
    }
}
// snippet.end

// snippet.simple_middleware
struct SimpleAuthMiddleware: RouterMiddleware {
    typealias Context = CustomContext

    func handle(
        _ input: Request,
        context: Context,
        next: (Request, Context) async throws -> Output
    ) async throws -> Response {
        var context = context
        guard
            let token = input.headers[.authorization]
        else {
            throw HTTPError(.unauthorized)
        }

        // Note: This is still not secure.
        // Token verification is missing from this example
        context.token = token

        // Pass along the chain to the next handler (middleware or route handler)
        return try await next(input, context)
    }
}
// snippet.end

// snippet.context_protocol
protocol AuthContext: RequestContext {
    var token: String? { get set }
}
// snippet.end

// snippet.context_protocol_middleware
struct AuthMiddleware<Context: AuthContext>: RouterMiddleware {
    func handle(
        _ input: Request,
        context: Context,
        next: (Request, Context) async throws -> Output
    ) async throws -> Response {
        var context = context
        guard
            let token = input.headers[.authorization]
        else {
            throw HTTPError(.unauthorized)
        }

        // Note: This is still not secure.
        // Token verification is missing from this example
        context.token = token

        // Pass along the chain to the next handler (middleware or route handler)
        return try await next(input, context)
    }
}
// snippet.end
