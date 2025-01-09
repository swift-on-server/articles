import JWTKit

// snippet.key_collection_init
let keyCollection = JWTKeyCollection()
// snippet.end

// snippet.key_collection_add_hmac
await keyCollection.add(hmac: "secret", digestAlgorithm: .sha256)
// snippet.end

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
// snippet.end

// snippet.jwt_sign
let payload = TestPayload(
    expiration: .init(value: .distantFuture),
    issuer: "myapp.com"
)

let token = try await keyCollection.sign(payload)
// snippet.end

// snippet.jwt_verify
let verifiedPayload = try await keyCollection.verify(
    token,
    as: TestPayload.self
)
// snippet.end

// snippet.auth_user_payload
struct UserPayload: JWTPayload {
    let userID: UUID
    let expiration: ExpirationClaim
    let roles: [String]

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case expiration = "exp"
        case roles
    }

    func verify(using key: some JWTAlgorithm) throws {
        try expiration.verifyNotExpired()
        guard roles.contains("admin") else {
            throw JWTError.claimVerificationFailure(
                name: "roles",
                reason: "User is not an admin"
            )
        }
    }

    init(from user: User) {
        self.userID = user.id
        self.expiration = .init(value: .init(timeIntervalSinceNow: 3600))  // Token expires in 1 hour
        self.roles = user.roles
    }
}
// snippet.end
