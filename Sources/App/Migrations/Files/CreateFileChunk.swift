import Vapor 
import Fluent

struct CreateFileChunk: AsyncMigration {
    func prepare(on database: Database)  async throws {
        try await database.schema("file_chunks")
            .id()
            .field("file_id", .uuid, .required, .references("files", "id", onDelete: .cascade))
            .field("chunk_number", .int, .required)
            .field("chunk_data", .data, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database)  async throws {
        try await database.schema("file_chunks").delete()
    }
}
