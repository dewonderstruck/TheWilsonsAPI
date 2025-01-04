import JWT
import Fluent
import Vapor

public struct JWTToken: JWTPayload, Authenticatable {
    // MARK: - Constants
    public enum Constants {
        public static let accessTokenExpirationTime: TimeInterval = 3600 // 1 hour
        public static let refreshTokenExpirationTime: TimeInterval = 2592000 // 30 days
    }
    
    // MARK: - Properties
    // OAuth2 standard claims
    public let iss: IssuerClaim?
    public let sub: SubjectClaim
    public let aud: AudienceClaim?
    public let exp: ExpirationClaim
    public let nbf: NotBeforeClaim?
    public let iat: IssuedAtClaim
    public let jti: String
    
    // Custom claims
    public let scopes: [Permission]
    public let type: TokenType
    
    // Make TokenType Sendable
    public enum TokenType: String, Codable, Sendable {
        case access
        case refresh
    }
    
    // MARK: - Initialization
    public init(
        subject: String,
        scopes: [Permission],
        expirationTime: TimeInterval,
        type: TokenType,
        issuer: String? = nil,
        audience: String? = nil
    ) {
        self.iss = issuer.map(IssuerClaim.init)
        self.sub = SubjectClaim(value: subject)
        self.aud = audience.map(AudienceClaim.init)
        self.exp = ExpirationClaim(value: Date().addingTimeInterval(expirationTime))
        self.nbf = NotBeforeClaim(value: Date())
        self.iat = IssuedAtClaim(value: Date())
        self.jti = UUID().uuidString
        self.scopes = scopes
        self.type = type
    }
    
    // MARK: - JWT Verification
    public func verify(using signer: JWTSigner) throws {
        try exp.verifyNotExpired()
        
        // Verify nbf (not before) if present
        if let nbf = nbf {
            let now = Date()
            guard now >= nbf.value else {
                throw JWTError.claimVerificationFailure(
                    name: "nbf",
                    reason: "Token not yet valid"
                )
            }
        }
    }
    
    // MARK: - Token Generation
    public static func generateTokens(
        for user: User,
        roles: [Role],
        on request: Request
    ) async throws -> AuthResponse {
        guard let userId = user.id else {
            throw Abort(.internalServerError)
        }
        
        // Get application config
        let issuer = Environment.get("JWT_ISSUER") ?? "api.yourapp.com"
        let audience = Environment.get("JWT_AUDIENCE") ?? "yourapp.com"
        
        // Collect all permissions from user's roles
        let permissions = roles.flatMap { $0.permissions }
        
        // Create access token
        let accessToken = JWTToken(
            subject: userId,
            scopes: permissions,
            expirationTime: Constants.accessTokenExpirationTime,
            type: .access,
            issuer: issuer,
            audience: audience
        )
        
        // Create refresh token with minimal scope
        let refreshToken = JWTToken(
            subject: userId,
            scopes: [],
            expirationTime: Constants.refreshTokenExpirationTime,
            type: .refresh,
            issuer: issuer,
            audience: audience
        )
        
        // Sign tokens
        let signedAccessToken = try request.jwt.sign(accessToken)
        let signedRefreshToken = try request.jwt.sign(refreshToken)
        
        // Create token records in database
        try await Token.createToken(
            jti: accessToken.jti,  // Use the token's jti instead of the signed token
            userId: userId,
            type: .access,
            expiresAt: accessToken.exp.value,
            request: request
        )
        
        try await Token.createToken(
            jti: refreshToken.jti,  // Use the token's jti instead of the signed token
            userId: userId,
            type: .refresh,
            expiresAt: refreshToken.exp.value,
            request: request
        )
        
        return AuthResponse(
            accessToken: signedAccessToken,
            refreshToken: signedRefreshToken,
            expiresIn: Constants.accessTokenExpirationTime
        )
    }
}

extension JWTToken {
    public struct AuthResponse: Content {
        public let accessToken: String
        public let refreshToken: String
        public let expiresIn: TimeInterval
        public var tokenType = "bearer"
    }
}

// Extension to handle token generation
extension JWTToken {
    /// Check if token is blacklisted
    public func isBlacklisted(on database: Database) async throws -> Bool {
        try await BlacklistedToken.query(on: database)
            .filter(\.$jti == jti)
            .first() != nil
    }
    
    /// Blacklist this token
    public func blacklist(on database: Database) async throws {
        let blacklistedToken = BlacklistedToken(
            jti: jti,
            userId: sub.value,
            expiresAt: exp.value,
            tokenType: type == .access ? .access : .refresh
        )
        
        try await blacklistedToken.save(on: database)
        
        // Also delete from active tokens
        try await Token.query(on: database)
            .filter(\.$jti == jti)
            .delete()
    }
} 
