import Fluent
import Vapor
import JWT
import JWTKit
import Crypto
import struct Foundation.UUID

// MARK: - Password Reset Token Model
final class PasswordResetToken: Model, Content, @unchecked Sendable {
    
    static let schema = "password_reset_tokens"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "value")
    var value: String
    
    @Field(key: "expires_at")
    var expiresAt: Date
    
    @Parent(key: "user_id")
    var user: User
    
    init() { }
    
    init(id: UUID? = nil, value: String, userID: User.IDValue, expiresAt: Date) {
        self.id = id
        self.value = value
        self.$user.id = userID
        self.expiresAt = expiresAt
    }
    
    static func generate(for user: User) throws -> PasswordResetToken {
        let random = [UInt8].random(count: 16)
        let data = Data(random)
        let digest = SHA256.hash(data: data)
        let value = digest.hex
        
        return .init(
            value: value,
            userID: user.id!,
            expiresAt: Date().addingTimeInterval(3600)
        )
    }
}
