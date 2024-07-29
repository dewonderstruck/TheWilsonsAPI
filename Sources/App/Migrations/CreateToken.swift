import Fluent
import Vapor

struct CreateToken: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(Token.schema)
            .id()
            .field("token", .string, .required)
            .field("hashed_refresh_token", .string)
            .field("userID", .uuid, .required, .references("users", "id"))
            .field("created_at", .datetime)
            .field("expires_at", .datetime)
            .field("refresh_token_expires_at", .datetime)
            .field("status", .string, .required)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(Token.schema).delete()
    }
}
