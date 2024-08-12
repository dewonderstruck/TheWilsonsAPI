import Vapor 
import Fluent

struct CreateFile: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("files")
            .id()
            .field("file_name", .string, .required)
            .field("file_size", .int, .required)
            .field("file_type", .string, .required)
            .field("upload_date", .datetime, .required)
            .field("storage_type", .string, .required)
            .field("bucket", .string, .required)
            .field("s3_etag", .string)
            .field("is_public", .bool, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database)  async throws {
        try await database.schema("files").delete()
    }
}
