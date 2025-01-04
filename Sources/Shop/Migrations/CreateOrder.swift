import Fluent

public struct CreateOrder: AsyncMigration {
    public init() {}
    public func prepare(on database: Database) async throws {
        try await database.schema("orders")
            .field("id", .string, .identifier(auto: false))
            .field("userId", .string, .required, .references("users", "id"))
            .field("productId", .string, .required)
            .field("status", .string, .required)
            .field("totalAmount", .double, .required)
            .field("measurements", .dictionary(of: .double), .required)
            .field("customizations", .dictionary(of: .string), .required)
            .field("selectedFabric", .string, .required)
            .field("selectedColor", .string, .required)
            .field("shippingAddress", .dictionary(of: .string), .required)
            .field("specialInstructions", .string)
            .field("createdAt", .datetime)
            .field("updatedAt", .datetime)
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("orders").delete()
    }
} 