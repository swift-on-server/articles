import Hummingbird
import HummingbirdRouter

let router = RouterBuilder(context: BasicRouterRequestContext.self) {
    TracingMiddleware()
    Get("test") { _, context in
        context.endpointPath
    }
    Get { _, context in
        context.endpointPath
    }
    Post("/test2") { _, context in
        context.endpointPath
    }
}
let app = Application(responder: router)
try await app.runService()
