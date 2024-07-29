import Fluent
import Vapor

struct CreateRolePermission: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(RolePermission.schema)
            .id()
            .field("name", .string, .required)
            .field("permissions", .array(of: .string), .required)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(RolePermission.schema).delete()
    }
}
