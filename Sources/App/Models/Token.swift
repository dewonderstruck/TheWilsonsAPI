import Fluent
import Vapor
import JWT
import JWTKit
import Crypto
import struct Foundation.UUID

/// Property wrappers interact poorly with `Sendable` checking, causing a warning for the `@ID` property
/// It is recommended you write your model with sendability checking on and then suppress the warning
/// afterwards with `@unchecked Sendable`.
final class Token: Model, Content, @unchecked Sendable {
    static let schema = "tokens"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "token")
    var tokenValue: String
    
    @Parent(key: "userID")
    var user: User
    
    @Field(key: "hashed_refresh_token")
    var hashedRefreshToken: String?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "expires_at", on: .create)
    var expiresAt: Date?
    
    @Timestamp(key: "refresh_token_expires_at", on: .create)
    var refreshTokenExpiresAt: Date?
    
    @Enum(key: "status")
    var status: TokenStatus
    
    init() { }
    
    init(id: UUID? = nil, tokenValue: String,
         hashedRefreshToken: String? = nil,
         userID: User.IDValue,
         createdAt: Date = Date(),
         expiresAt: Date,
         refreshTokenExpiresAt: Date,
         status: TokenStatus = .active) {
        self.id = id
        self.tokenValue = tokenValue
        self.hashedRefreshToken = hashedRefreshToken
        self.$user.id = userID
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.refreshTokenExpiresAt = refreshTokenExpiresAt
        self.status = status
    }
    
    static func generate(for user: User, using req: Request) async throws -> (Token, String) {
        let accessTokenExpirationTime: TimeInterval = 60 * 60 * 1 // 1 hour
        let refreshTokenExpirationTime: TimeInterval = 60 * 60 * 24 * 30 // 30 days
        
        let accessTokenExpirationDate = Date().addingTimeInterval(accessTokenExpirationTime)
        let refreshTokenExpirationDate = Date().addingTimeInterval(refreshTokenExpirationTime)
        
        let accessTokenPayload = UserPayload(
            subject: SubjectClaim(value: user.id?.uuidString ?? ""),
            expiration: ExpirationClaim(value: accessTokenExpirationDate),
            issuedAt: IssuedAtClaim(value: Date()),
            issuer: IssuerClaim(value: "v1.vapr-auth.api.tktchurch.com")
        )
        
        let accessTokenString = try await req.jwt.sign(accessTokenPayload, kid: "private")
        
        // Generate a secure random string for the refresh token
        let refreshTokenString = try generateSecureRandomString()
        let hashedRefreshToken = try hashRefreshToken(refreshTokenString)
        
        let token = try Token(
            tokenValue: accessTokenString,
            hashedRefreshToken: hashedRefreshToken,
            userID: user.requireID(),
            createdAt: Date(),
            expiresAt: accessTokenExpirationDate,
            refreshTokenExpiresAt: refreshTokenExpirationDate,
            status: .active
        )
        
        return (token, refreshTokenString)
    }
    
    private static func generateSecureRandomString() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status == errSecSuccess {
            return Data(bytes).base64URLEncodedString()
        } else {
            throw Abort(.internalServerError, reason: "Failed to generate secure random string")
        }
    }
    
    static func hashRefreshToken(_ token: String) throws -> String {
        guard let data = token.data(using: .utf8) else {
            throw Abort(.internalServerError, reason: "Failed to convert token to data")
        }
        let digest = SHA256.hash(data: data)
        return digest.hex
    }
}

enum TokenStatus: String, Codable {
    case active
    case revoked
}

extension SHA256.Digest {
    var hex: String {
        return self.compactMap { String(format: "%02x", $0) }.joined()
    }
}

extension Data {
    func base64URLEncodedString() -> String {
        return self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
