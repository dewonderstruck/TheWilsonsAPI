import Fluent

public struct CreateProductCollection: AsyncMigration {
    public init() {}
    
    public func prepare(on database: Database) async throws {
        try await database.schema("product_collections")
            .id()
            .field("productId", .string, .required, .references("products", "id"))
            .field("collectionId", .string, .required, .references("collections", "id"))
            .field("position", .int, .required)
            .field("featured", .bool, .required)
            .field("createdAt", .datetime)
            .unique(on: "productId", "collectionId")
            .create()
    }
    
    public func revert(on database: Database) async throws {
        try await database.schema("product_collections").delete()
    }
} 