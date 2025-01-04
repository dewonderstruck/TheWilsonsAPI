import Fluent
import Vapor
import Foundation

final class Token: Model, @unchecked Sendable {
    static let schema = "tokens"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: FieldKeys.jti)
    var jti: String
    
    @Parent(key: FieldKeys.userId)
    var user: User
    
    @Field(key: FieldKeys.type)
    var type: TokenType
    
    @Field(key: FieldKeys.expiresAt)
    var expiresAt: Date
    
    @Field(key: FieldKeys.deviceInfo)
    var deviceInfo: DeviceInfo?
    
    @Field(key: FieldKeys.lastUsedAt)
    var lastUsedAt: Date
    
    @Timestamp(key: FieldKeys.createdAt, on: .create)
    var createdAt: Date?
    
    init() { }
    
    init(
        id: UUID? = nil,
        jti: String,
        userId: String,
        type: TokenType,
        expiresAt: Date,
        deviceInfo: DeviceInfo? = nil,
        lastUsedAt: Date = Date()
    ) {
        self.id = id
        self.jti = jti
        self.$user.id = userId
        self.type = type
        self.expiresAt = expiresAt
        self.deviceInfo = deviceInfo
        self.lastUsedAt = lastUsedAt
    }
    
    enum TokenType: String, Codable, Sendable {
        case access
        case refresh
    }
    
    struct DeviceInfo: Codable, Sendable {
        var deviceId: String?
        var deviceType: DeviceType
        var deviceName: String?
        var deviceModel: String?
        var osName: String?
        var osVersion: String?
        var appVersion: String?
        var ipAddress: String?
        var userAgent: String?
        var lastLocation: String?
        
        enum DeviceType: String, Codable {
            case mobile
            case tablet
            case desktop
            case other
        }
    }
}

extension Token {
    struct FieldKeys {
        static let jti: FieldKey = "jti"
        static let userId: FieldKey = "user_id"
        static let type: FieldKey = "type"
        static let expiresAt: FieldKey = "expires_at"
        static let deviceInfo: FieldKey = "device_info"
        static let lastUsedAt: FieldKey = "last_used_at"
        static let createdAt: FieldKey = "created_at"
    }
}

extension Token {
    struct DTO: Content {
        let id: UUID?
        let deviceInfo: DeviceInfo?
        let lastUsedAt: Date
        let createdAt: Date?
        let expiresAt: Date
        
        init(token: Token) {
            self.id = token.id
            self.deviceInfo = token.deviceInfo
            self.lastUsedAt = token.lastUsedAt
            self.createdAt = token.createdAt
            self.expiresAt = token.expiresAt
        }
    }
}

// MARK: - Helper Methods
extension Token {
    static func createToken(
        jti: String,
        userId: String,
        type: TokenType,
        expiresAt: Date,
        request: Request
    ) async throws -> Token {
        let deviceInfo = try extractDeviceInfo(from: request)
        let token = Token(
            jti: jti,
            userId: userId,
            type: type,
            expiresAt: expiresAt,
            deviceInfo: deviceInfo
        )
        try await token.save(on: request.authDB)
        return token
    }
    
    static func extractDeviceInfo(from request: Request) throws -> DeviceInfo {
        let userAgent = request.headers.first(name: .userAgent)
        let deviceType: DeviceInfo.DeviceType = {
            guard let ua = userAgent?.lowercased() else { return .other }
            if ua.contains("mobile") { return .mobile }
            if ua.contains("tablet") { return .tablet }
            if ua.contains("mozilla") || ua.contains("chrome") || ua.contains("safari") { return .desktop }
            return .other
        }()
        
        return DeviceInfo(
            deviceId: request.headers["X-Device-ID"].first,
            deviceType: deviceType,
            deviceName: request.headers["X-Device-Name"].first,
            deviceModel: request.headers["X-Device-Model"].first,
            osName: request.headers["X-OS-Name"].first,
            osVersion: request.headers["X-OS-Version"].first,
            appVersion: request.headers["X-App-Version"].first,
            ipAddress: request.remoteAddress?.hostname,
            userAgent: userAgent,
            lastLocation: request.headers["X-Location"].first
        )
    }
    
    static func listUserDevices(userId: String, on database: Database) async throws -> [Token] {
        try await Token.query(on: database)
            .filter(\.$user.$id == userId)
            .filter(\.$type == .refresh)
            .filter(\.$expiresAt > Date())
            .sort(\.$lastUsedAt, .descending)
            .all()
    }
    
    static func revokeAllTokens(
        userId: String,
        except currentTokenId: UUID? = nil,
        on database: Database
    ) async throws {
        var query = Token.query(on: database)
            .filter(\.$user.$id == userId)
        
        if let currentTokenId {
            // Get the current refresh token
            guard let currentToken = try await Token.find(currentTokenId, on: database),
                  currentToken.type == .refresh else {
                throw Abort(.badRequest, reason: "Invalid token ID")
            }
            
            // Exclude current refresh token and its associated access token
            query = query.group(.and) { group in
                group.filter(\.$id != currentTokenId)
                    .filter(\.$jti != currentToken.jti)
            }
        }
        
        let tokens = try await query.all()
        
        // Add tokens to blacklist
        for token in tokens {
            let blacklistedToken = BlacklistedToken(
                jti: token.jti,
                userId: userId,
                expiresAt: token.expiresAt,
                tokenType: token.type == .access ? .access : .refresh
            )
            try await blacklistedToken.save(on: database)
        }
        
        // Delete tokens
        try await query.delete()
    }
    
    static func revokeToken(
        id: UUID,
        userId: String,
        on database: Database
    ) async throws {
        // Get the refresh token
        guard let token = try await Token.query(on: database)
            .filter(\.$id == id)
            .filter(\.$user.$id == userId)
            .first()
        else {
            throw Abort(.notFound)
        }
        
        // Add token to blacklist
        let blacklistedToken = BlacklistedToken(
            jti: token.jti,
            userId: userId,
            expiresAt: token.expiresAt,
            tokenType: token.type == .access ? .access : .refresh
        )
        
        try await blacklistedToken.save(on: database)
        
        // Delete the token
        try await Token.query(on: database)
            .filter(\.$id == id)
            .delete()
    }
    
    static func updateLastUsed(jti: String, on database: Database) async throws {
        // Get the token
        guard let token = try await Token.query(on: database)
            .filter(\.$jti == jti)
            .first() else {
            return
        }
        
        // Update last used for this token
        try await Token.query(on: database)
            .filter(\.$jti == jti)
            .set(\.$lastUsedAt, to: Date())
            .update()
        
        // If this is an access token, also update its associated refresh token
        if token.type == .access {
            try await Token.query(on: database)
                .filter(\.$user.$id == token.$user.id)
                .filter(\.$type == .refresh)
                .set(\.$lastUsedAt, to: Date())
                .update()
        }
    }
} 
