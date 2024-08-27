import Fluent 
import Vapor

struct CreatePaymentLink: AsyncMigration {
    
    func prepare(on database: Database) async throws {
        try await database.schema("payment_links")
            .id()
            .field("name", .string, .required)
            .field("description", .string, .required)
            .field("amount", .json, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .field("user_created", .uuid, .required, .references("users", "id"))
            .field("user_updated", .uuid, .required, .references("users", "id"))
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("payment_links").delete()
    }
}