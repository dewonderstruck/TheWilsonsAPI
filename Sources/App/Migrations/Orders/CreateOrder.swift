import Fluent

struct CreateOrder: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(Order.schema)
            .id()
            .field("user_id", .uuid, .required, .references("users", "id"))
            .field("total", .double, .required)
            .field("status", .string, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(Order.schema).delete()
    }
}