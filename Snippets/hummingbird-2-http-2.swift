// snippet.imports
import Hummingbird
import HummingbirdHTTP2
import NIOCore
import NIOHTTPTypesHTTP2
import NIOSSL
// snippet.end

// snippet.tls
let certificateChainFilePath = "/path/to/server.crt"
let privateKeyFilePath = "/path/to/private-key.pem"

let certificateChain = try NIOSSLCertificate.fromPEMFile(certificateChainFilePath)
let privateKey = try NIOSSLPrivateKey(file: privateKeyFilePath, format: .pem)
let tlsConfiguration = TLSConfiguration.makeServerConfiguration(
    certificateChain: certificateChain.map { .certificate($0) },
    privateKey: .privateKey(privateKey)
)
// snippet.end

let router = Router()

// snippet.application
let app = try Application(
    router: router,
    server: .http2Upgrade(tlsConfiguration: tlsConfiguration)
)

try await app.runService()
// snippet.end