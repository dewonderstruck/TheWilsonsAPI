import Fluent

public struct CreateCustomizationOption: AsyncMigration {
    public init() {}
    
    public func prepare(on database: Database) async throws {
        try await database.schema("customization_options")
            .field("id", .string, .identifier(auto: false))
            .field("name", .string, .required)
            .field("type", .string, .required)
            .field("description", .string, .required)
            .field("options", .dictionary(of: .dictionary(of: .string)), .required)
            .field("displayOrder", .int, .required)
            .field("isRequired", .bool, .required)
            .field("expertSuggestions", .dictionary(of: .string))
            .field("metadata", .dictionary(of: .string))
            .field("productId", .string, .required, .references("products", "id"))
            .field("createdAt", .datetime)
            .field("updatedAt", .datetime)
            .create()
    }
    
    public func revert(on database: Database) async throws {
        try await database.schema("customization_options").delete()
    }
} 