import Fluent

public struct CreateProduct: AsyncMigration {
    public init() {}
    public func prepare(on database: Database) async throws {
        try await database.schema("products")
            .field("id", .string, .identifier(auto: false))
            .field("storeId", .string, .required, .references("stores", "id"))
            .field("name", .string, .required)
            .field("description", .string, .required)
            .field("pricing", .dictionary(of: .double), .required)
            .field("category", .string, .required)
            .field("fabricOptions", .array(of: .string), .required)
            .field("availableColors", .array(of: .string), .required)
            .field("customizationOptions", .dictionary(of: .array(of: .string)), .required)
            .field("images", .array(of: .string), .required)
            .field("stockStatus", .string, .required)
            .field("isActive", .bool, .required)
            .field("createdAt", .datetime)
            .field("updatedAt", .datetime)
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("products").delete()
    }
} 