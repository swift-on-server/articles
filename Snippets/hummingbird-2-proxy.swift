// snippet.imports
import AsyncHTTPClient
import Hummingbird
import Logging
import NIOCore
import NIOPosix
import ServiceLifecycle
// snippet.end

// snippet.forwarding
func forward(
    request: Request,
    targetHost: String,
    httpClient: HTTPClient,
    context: some RequestContext
) async throws -> Response {
    // 1.
    let query = request.uri.query.map { "?\($0)" } ?? ""
    var clientRequest = HTTPClientRequest(url: "https://\(targetHost)\(request.uri.path)\(query)")
    clientRequest.method = .init(request.method)
    clientRequest.headers = .init(request.headers)

    // 2.
    let contentLength = if let header = request.headers[.contentLength], let value = Int(header) {
        HTTPClientRequest.Body.Length.known(value)
    } else {
        HTTPClientRequest.Body.Length.unknown
    }
    clientRequest.body = .stream(
        request.body,
        length: contentLength
    )

    // 3.
    let response = try await httpClient.execute(clientRequest, timeout: .seconds(60))

    // 4.
    return Response(
        status: HTTPResponse.Status(code: Int(response.status.code), reasonPhrase: response.status.reasonPhrase),
        headers: HTTPFields(response.headers, splitCookie: false),
        body: ResponseBody(asyncSequence: response.body)
    )
}
// snippet.end

// snippet.middleware
struct ProxyServerMiddleware<Context: RequestContext>: RouterMiddleware {
    var httpClient: HTTPClient = .shared
    let targetHost: String

    func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        try await forward(
            request: request,
            targetHost: targetHost,
            httpClient: httpClient,
            context: context
        )
    }
}
// snippet.end

do {
    // snippet.middleware-router
    let router = Router()
    router.add(middleware: ProxyServerMiddleware(targetHost: "example.com"))
    // snippet.end

    // snippet.setup-router
    let app = Application(
        router: router
    )
    // snippet.end

    _ = app
}

do {
    // snippet.route
    let router = Router()
    router.get("**") { request, context in
        try await forward(
            request: request,
            targetHost: "example.com",
            httpClient: .shared,
            context: context
        )
    }
    // snippet.end

    _ = router
}

// snippet.responder
struct ProxyServerResponder<Context: RequestContext>: HTTPResponder {
    let targetHost: String

    func respond(to request: Request, context: Context) async throws -> Response {
        try await forward(
            request: request,
            targetHost: targetHost,
            httpClient: .shared,
            context: context
        )
    }
}
// snippet.end

do {
    // snippet.setup-responder
    let app = Application(
        responder: ProxyServerResponder<BasicRequestContext>(targetHost: "example.com")
    )
    // snippet.end

    _ = app
}
