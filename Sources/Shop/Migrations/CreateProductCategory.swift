import Fluent

public struct CreateProductCategory: AsyncMigration {
    public init() {}
    
    public func prepare(on database: Database) async throws {
        try await database.schema("product_categories")
            .id()
            .field("productId", .string, .required, .references("products", "id"))
            .field("categoryId", .string, .required, .references("categories", "id"))
            .field("displayOrder", .int, .required)
            .field("createdAt", .datetime)
            .unique(on: "productId", "categoryId")
            .create()
    }
    
    public func revert(on database: Database) async throws {
        try await database.schema("product_categories").delete()
    }
} 