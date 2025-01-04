import Fluent

public struct CreateStore: AsyncMigration {
    public init() {}   
    public func prepare(on database: Database) async throws {
        try await database.schema("stores")
            .field("id", .string, .identifier(auto: false))
            .field("name", .string, .required)
            .field("region", .string, .required)
            .field("currency", .string, .required)
            .field("address", .dictionary(of: .string), .required)
            .field("contactInfo", .dictionary(of: .string), .required)
            .field("timezone", .string, .required)
            .field("isActive", .bool, .required)
            .field("createdAt", .datetime)
            .field("updatedAt", .datetime)
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("stores").delete()
    }
} 