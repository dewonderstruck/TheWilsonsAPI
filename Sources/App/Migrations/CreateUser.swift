import Fluent

struct CreateUser: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(User.schema)
            .id()
            .field("first_name", .string)
            .field("last_name", .string)
            .field("email", .string, .required)
            .field("password", .string, .required)
            .field("status", .string, .required)
            .field("role", .array(of: .string), .required)
            .field("provider", .string, .required)
            .field("provider_user_id", .string)
            .field("external_identifier", .string)
            .field("member_id", .string)
            .field("account_type", .string, .required)
            .field("email_verified", .bool)
            .field("phone_number_verified", .bool)
            .field("phone_number", .string)
            .field("address", .string)
            .field("area", .string)
            .unique(on: "email")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(User.schema).delete()
    }
}
