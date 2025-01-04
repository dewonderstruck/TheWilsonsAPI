import Fluent

public struct CreateCategory: AsyncMigration {
    public init() {}
    
    public func prepare(on database: Database) async throws {
        try await database.schema("categories")
            .field("id", .string, .identifier(auto: false))
            .field("name", .string, .required)
            .field("slug", .string, .required)
            .field("description", .string, .required)
            .field("parentId", .string, .references("categories", "id"))
            .field("metadata", .dictionary(of: .string))
            .field("displayOrder", .int, .required)
            .field("isActive", .bool, .required)
            .field("type", .string, .required)
            .field("imageUrl", .string)
            .field("createdAt", .datetime)
            .field("updatedAt", .datetime)
            .unique(on: "slug")
            .create()
    }
    
    public func revert(on database: Database) async throws {
        try await database.schema("categories").delete()
    }
} 