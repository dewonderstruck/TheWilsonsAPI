import Fluent

public struct CreateUser: AsyncMigration {
    public init() {}
    
    public func prepare(on database: Database) async throws {
        try await database.schema(User.schema)
            .id()
            .field(User.FieldKeys.email, .string, .required)
            .field(User.FieldKeys.passwordHash, .string, .required)
            .field(User.FieldKeys.firstName, .string)
            .field(User.FieldKeys.lastName, .string)
            .field(User.FieldKeys.status, .string, .required)
            .field(User.FieldKeys.provider, .string, .required)
            .field(User.FieldKeys.providerInfo, .dictionary)
            .field(User.FieldKeys.emailVerified, .bool, .required)
            .field(User.FieldKeys.phoneNumberVerified, .bool, .required)
            .field(User.FieldKeys.phoneNumber, .string)
            .field(User.FieldKeys.lastLoginAt, .datetime)
            .field(User.FieldKeys.lastLoginIp, .string)
            .field(User.FieldKeys.validSince, .datetime)
            .unique(on: User.FieldKeys.email)
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema(User.schema).delete()
    }
} 
