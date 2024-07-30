import Fluent

struct CreateOrderItem: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(OrderItem.schema)
            .id()
            .field("order_id", .uuid, .required, .references("orders", "id"))
            .field("product_id", .uuid, .required, .references("products", "id"))
            .field("quantity", .int, .required)
            .field("price", .double, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(OrderItem.schema).delete()
    }
}