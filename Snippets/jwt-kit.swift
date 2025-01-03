import JWTKit

// snippet.key_collection_init
let keyCollection = JWTKeyCollection()

// snippet.key_collection_add_hmac
await keyCollection.add(hmac: "secret", digestAlgorithm: .sha256)

// snippet.payload_struct
struct TestPayload: JWTPayload {
    var expiration: ExpirationClaim
    var issuer: IssuerClaim

    enum CodingKeys: String, CodingKey {
        case expiration = "exp"
        case issuer = "iss"
    }

    func verify(using key: some JWTAlgorithm) throws {
        try self.expiration.verifyNotExpired()
    }
}

// snippet.jwt_sign
let payload = TestPayload(
    expiration: .init(value: .distantFuture),
    issuer: "myapp.com"
)

let token = try await keyCollection.sign(payload)

// snippet.jwt_verify
let verifiedPayload = try await keyCollection.verify(token, as: TestPayload.self)
