// snippet.processInfo
import Foundation
// snippet.end
// snippet.hummingbird
import Hummingbird
import Logging

let env = ProcessInfo.processInfo.environment

let value = env["LOG_LEVEL"] ?? "trace"

print(value)

func buildApplication(
    configuration: ApplicationConfiguration
) async throws -> some ApplicationProtocol {
    var logger = Logger(label: "hummingbird-logger")
    logger.logLevel = .trace

    let env = Environment()
    // let env = try await Environment.dotEnv()
    let logLevel = env.get("LOG_LEVEL")

    if let logLevel, let logLevel = Logger.Level(rawValue: logLevel) {
        logger.logLevel = logLevel
    }

    let router = Router()
    router.get("/") { _, _ in
        "Hello"
    }

    let app = Application(
        router: router,
        configuration: configuration,
        logger: logger
    )
    return app
}
// snippet.end
