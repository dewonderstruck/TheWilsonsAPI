import Fluent

struct CreateProductCategory: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(ProductCategory.schema)
            .id()
            .field("product_id", .uuid, .required, .references("products", "id"))
            .field("category_id", .uuid, .required, .references("categories", "id"))
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(ProductCategory.schema).delete()
    }
}
