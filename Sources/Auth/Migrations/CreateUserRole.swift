import Fluent

public struct CreateUserRole: AsyncMigration {
    public init() {}
    
    public func prepare(on database: Database) async throws {
        try await database.schema(UserRole.schema)
            .id()
            .field(UserRole.FieldKeys.userId, .uuid, .required, .references(User.schema, .id))
            .field(UserRole.FieldKeys.roleId, .uuid, .required, .references(Role.schema, .id))
            .field(UserRole.FieldKeys.createdAt, .datetime)
            .unique(on: UserRole.FieldKeys.userId, UserRole.FieldKeys.roleId)
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema(UserRole.schema).delete()
    }
} 
