import Fluent

public struct CreateCollection: AsyncMigration {
    public init() {}
    
    public func prepare(on database: Database) async throws {
        try await database.schema("collections")
            .field("id", .string, .identifier(auto: false))
            .field("title", .string, .required)
            .field("slug", .string, .required)
            .field("description", .string, .required)
            .field("imageUrl", .string)
            .field("isAutomated", .bool, .required)
            .field("conditions", .array(of: .dictionary), .required)
            .field("sortOrder", .string, .required)
            .field("displayOrder", .int, .required)
            .field("isActive", .bool, .required)
            .field("metadata", .dictionary(of: .string))
            .field("createdAt", .datetime)
            .field("updatedAt", .datetime)
            .unique(on: "slug")
            .create()
    }
    
    public func revert(on database: Database) async throws {
        try await database.schema("collections").delete()
    }
} 