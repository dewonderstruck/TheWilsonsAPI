import Fluent

public struct CreateToken: AsyncMigration {
    public init() {}
    
    public func prepare(on database: Database) async throws {
        try await database.schema(Token.schema)
            .id()
            .field(Token.FieldKeys.jti, .string, .required)
            .field(Token.FieldKeys.userId, .uuid, .required, .references(User.schema, .id, onDelete: .cascade))
            .field(Token.FieldKeys.type, .string, .required)
            .field(Token.FieldKeys.expiresAt, .datetime, .required)
            .field(Token.FieldKeys.deviceInfo, .dictionary)
            .field(Token.FieldKeys.lastUsedAt, .datetime, .required)
            .field(Token.FieldKeys.createdAt, .datetime)
            .unique(on: Token.FieldKeys.jti)
            .create()
        
        // Create indexes for faster lookups
        try await database.schema(Token.schema)
            .field(Token.FieldKeys.userId, .uuid, .required)
            .field(Token.FieldKeys.expiresAt, .datetime, .required)
            .field(Token.FieldKeys.lastUsedAt, .datetime, .required)
            .update()
    }
    
    public func revert(on database: Database) async throws {
        try await database.schema(Token.schema).delete()
    }
} 