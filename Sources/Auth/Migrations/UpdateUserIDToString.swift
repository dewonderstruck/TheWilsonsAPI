import Fluent

public struct UpdateUserIDToString: AsyncMigration {
    public init() {}
    
    public func prepare(on database: Database) async throws {
        try await database.schema(User.schema)
            .deleteField("id")
            .field("id", .string, .identifier(auto: false))
            .update()
    }
    
    public func revert(on database: Database) async throws {
        try await database.schema(User.schema)
            .deleteField("id")
            .field("id", .uuid, .identifier(auto: true))
            .update()
    }
} 