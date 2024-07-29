import Vapor
import Fluent 

struct CreateKey: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("keys")
           .id()
            .field("kid", .string, .required)
            .field("key_type", .string, .required)
            .field("key_data", .string, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .field("status", .string, .required)
            .unique(on: "kid")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("keys").delete()
    }
}