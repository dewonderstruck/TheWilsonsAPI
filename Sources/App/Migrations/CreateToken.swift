import Fluent
import Vapor

struct CreateToken: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("tokens")
            .id() 
            .field("tokenValue", .string, .required) 
            .field("userID", .uuid, .required)
            .field("created_at", .datetime)
            .field("expires_at", .datetime) 
            .create() 
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("tokens").delete()
    }
}
