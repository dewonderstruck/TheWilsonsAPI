import Fluent
import Vapor

struct CreateUserRolePermission: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(UserRolePermission.schema)
            .id()
            .field("user_id", .uuid, .required, .references("users", "id"))
            .field("role_permission_id", .uuid, .required, .references("role_permissions", "id"))
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(UserRolePermission.schema).delete()
    }
}
