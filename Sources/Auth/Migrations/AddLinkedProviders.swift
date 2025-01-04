import Fluent

public struct AddLinkedProviders: AsyncMigration {
    public init() {}
    
    public func prepare(on database: Database) async throws {
        try await database.schema(User.schema)
            .field(User.FieldKeys.linkedProviders, .array)
            .update()
    }
    
    public func revert(on database: Database) async throws {
        try await database.schema(User.schema)
            .deleteField(User.FieldKeys.linkedProviders)
            .update()
    }
} 