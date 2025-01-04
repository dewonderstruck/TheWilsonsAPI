import Fluent

public struct CreateRole: AsyncMigration {
    public init() {}
    
    public func prepare(on database: Database) async throws {
        try await database.schema(Role.schema)
            .id()
            .field(Role.FieldKeys.name, .string, .required)
            .field(Role.FieldKeys.description, .string, .required)
            .field(Role.FieldKeys.permissions, .array(of: .string), .required)
            .field(Role.FieldKeys.isSystem, .bool, .required)
            .unique(on: Role.FieldKeys.name)
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema(Role.schema).delete()
    }
} 
