import JWTKit
import Foundation

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

// snippet.auth_user_role_claim
struct RoleClaim: JWTClaim {
    var value: [String]

    func verifyAdmin() throws {
        guard value.contains("admin") else {
            throw JWTError.claimVerificationFailure(
                failedClaim: self,
                reason: "User is not an admin"
            )
        }
    }
}
// snippet.end

struct User {
    var id: Int
    var roles: RoleClaim
}

// snippet.auth_user_payload
struct UserPayload: JWTPayload {
    let userID: Int
    let expiration: ExpirationClaim
    let roles: RoleClaim

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case expiration = "exp"
        case roles
    }

    func verify(using key: some JWTAlgorithm) throws {
        try expiration.verifyNotExpired()
        try roles.verifyAdmin()
    }

    init(from user: User) {
        self.userID = user.id
        self.expiration = .init(value: .init(timeIntervalSinceNow: 3600))  // Token expires in 1 hour
        self.roles = user.roles
    }
}
// snippet.end
