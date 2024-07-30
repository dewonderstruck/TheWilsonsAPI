import Fluent

struct CreateTransaction: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(Transaction.schema)
            .id()
            .field("order_id", .uuid, .required, .references("orders", "id"))
            .field("amount", .double, .required)
            .field("status", .string, .required)
            .field("payment_gateway", .string, .required)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(Transaction.schema).delete()
    }
}
