import Fluent

public struct CreateBlacklistedToken: AsyncMigration {
    public init() {}
    
    public func prepare(on database: Database) async throws {
        try await database.schema(BlacklistedToken.schema)
            .id()
            .field(BlacklistedToken.FieldKeys.jti, .string, .required)
            .field(BlacklistedToken.FieldKeys.userId, .uuid, .required)
            .field(BlacklistedToken.FieldKeys.expiresAt, .datetime, .required)
            .field(BlacklistedToken.FieldKeys.tokenType, .string, .required)
            .field(BlacklistedToken.FieldKeys.blacklistedAt, .datetime)
            .unique(on: BlacklistedToken.FieldKeys.jti)
            .create()
        
        // Create index for faster lookups and automatic cleanup
        try await database.schema(BlacklistedToken.schema)
            .field(BlacklistedToken.FieldKeys.expiresAt, .datetime, .required)
            .update()
    }
    
    public func revert(on database: Database) async throws {
        try await database.schema(BlacklistedToken.schema).delete()
    }
} 