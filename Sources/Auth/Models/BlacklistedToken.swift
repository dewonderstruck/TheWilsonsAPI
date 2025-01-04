import Fluent
import Foundation

final class BlacklistedToken: Model, @unchecked Sendable {
    static let schema = "blacklisted_tokens"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: FieldKeys.jti)
    var jti: String
    
    @Field(key: FieldKeys.userId)
    var userId: String
    
    @Field(key: FieldKeys.expiresAt)
    var expiresAt: Date
    
    @Field(key: FieldKeys.tokenType)
    var tokenType: TokenType
    
    @Timestamp(key: FieldKeys.blacklistedAt, on: .create)
    var blacklistedAt: Date?
    
    init() { }
    
    init(
        id: UUID? = nil,
        jti: String,
        userId: String,
        expiresAt: Date,
        tokenType: TokenType
    ) {
        self.id = id
        self.jti = jti
        self.userId = userId
        self.expiresAt = expiresAt
        self.tokenType = tokenType
    }
    
    enum TokenType: String, Codable, Sendable {
        case access
        case refresh
    }
}

extension BlacklistedToken {
    struct FieldKeys {
        static let jti: FieldKey = "jti"
        static let userId: FieldKey = "user_id"
        static let expiresAt: FieldKey = "expires_at"
        static let tokenType: FieldKey = "token_type"
        static let blacklistedAt: FieldKey = "blacklisted_at"
    }
} 