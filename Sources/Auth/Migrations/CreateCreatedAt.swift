import Fluent

public struct CreateCreatedAt: AsyncMigration {
    public init() {}
    
    public func prepare(on database: Database) async throws {
        try await database.schema(User.schema)
            .field(User.FieldKeys.createdAt, .datetime, .required)
            .update()
    }

    public func revert(on database: Database) async throws {
        try await database.schema(User.schema)
            .field(User.FieldKeys.createdAt, .datetime, .required)
            .delete()
    }
}   
