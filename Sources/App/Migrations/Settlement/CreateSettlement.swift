import Fluent

struct CreateSettlement: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(Settlement.schema)
            .id()
            .field("transaction_id", .uuid, .required, .references("transactions", "id"))
            .field("amount", .double, .required)
            .field("status", .string, .required)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(Settlement.schema).delete()
    }
}