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
    
    @Timestamp(key: "expires_at", on: .none)
    var expiresAt: Date?
    
    @Field(key: "expires_at_timestamp")
    var expiresAtTimestamp: TimeInterval?
    
    @Timestamp(key: "refresh_token_expires_at", on: .none)
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
         expiresAtTimestamp: TimeInterval? = nil,
         status: TokenStatus = .active) {
        self.id = id
        self.tokenValue = tokenValue
        self.hashedRefreshToken = hashedRefreshToken
        self.$user.id = userID
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.expiresAtTimestamp = expiresAtTimestamp
        self.refreshTokenExpiresAt = refreshTokenExpiresAt
        self.status = status
    }
    
    static func generate(for user: User, using req: Request) async throws -> (Token, String) {
        let accessTokenExpirationTime: TimeInterval = 60 * 60 * 1 // 1 hour
        let refreshTokenExpirationTime: TimeInterval = 60 * 60 * 24 * 30 // 30 days
        
        let accessTokenExpirationDate = Date().addingTimeInterval(accessTokenExpirationTime)
        let refreshTokenExpirationDate = Date().addingTimeInterval(refreshTokenExpirationTime)
        
        // Fetch user's role permissions
        let rolePermissions = try await user.$rolePermissions.get(on: req.db)
        
        // Generate scopes based on role permissions
        let scopes = try await generateScopes(for: user, rolePermissions: rolePermissions)

        // Generate roles based on role permissions
        let roles = try await generateRoles(for: user, rolePermissions: rolePermissions)
        
        let accessTokenPayload = UserPayload(
            role: roles,
            scope: scopes,
            subject: SubjectClaim(value: user.id?.uuidString ?? ""),
            expiration: ExpirationClaim(value: accessTokenExpirationDate),
            issuedAt: IssuedAtClaim(value: Date()),
            issuer: IssuerClaim(value: "https://securetoken.dewonderstruck.com/thewilsons"),
            aud: AudienceClaim(value: "thewilsons")
        )
        
        // Load private keys from the database
        let privateKeys = try await Key.query(on: req.db).filter(\.$keyType == .privateKey).filter(\.$status == .active).all()
        
        guard let selectedPrivateKey = privateKeys.randomElement() else {
            throw Abort(.internalServerError, reason: "No private key found in the database.")
        }
        
        let privateKeyKid = JWKIdentifier(string: selectedPrivateKey.kid)
        
        let accessTokenString = try await req.jwt.sign(accessTokenPayload, kid: privateKeyKid)
        
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
    
    // Helper function to generate scopes
    private static func generateScopes(for user: User, rolePermissions: [RolePermission]) async throws -> String {
        var scopes: Set<String> = []
        
        // Add role permissions to scopes
        for rolePermission in rolePermissions {
            for permission in rolePermission.permissions {
                scopes.insert("\(permission.rawValue)")
            }
        }
        
        // Convert Set to space-separated String
        return scopes.joined(separator: " ")
    }

    // Helper function to generate roles
    private static func generateRoles(for user: User, rolePermissions: [RolePermission]) async throws -> String {
        var roles: Set<String> = []
        
        // Add role permissions to roles
        for rolePermission in rolePermissions {
            roles.insert(rolePermission.name)
        }
        
        // Convert Set to space-separated String
        return roles.joined(separator: " ")
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
