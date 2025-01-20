import Hummingbird

let router = Router()

// snippet.middleware
router.add(middleware: CORSMiddleware())
// snippet.end

// snippet.custom_middleware
router.add(middleware: CORSMiddleware(
    allowOrigin: .custom("http://example.com"),
    allowHeaders: [.accept, .contentType],
    allowMethods: [.get, .post],
    allowCredentials: true,
    maxAge: .seconds(3600))
)
// snippet.end
