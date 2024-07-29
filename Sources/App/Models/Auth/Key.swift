import Fluent
import Vapor

final class Key: Model, Content, @unchecked Sendable {
    static let schema = "keys"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "kid")
    var kid: String

    @Field(key: "key_type")
    var keyType: KeyType

    @Field(key: "key_data")
    var keyData: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Field(key: "status")
    var status: Status

    init() { }

    init(
        kid: UUID, 
        keyType: KeyType, 
        keyData: String,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        status: Status = .active
        ) {
        self.kid = kid.uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        self.keyType = keyType
        self.keyData = keyData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.status = status
    }

    enum KeyType: String, Codable {
        case privateKey = "private"
        case publicKey = "public"
    }
}
