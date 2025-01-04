import Fluent

public struct SeedDefaultRoles: AsyncMigration {
    public init() {}
    
    public func prepare(on database: Database) async throws {
        // Create default roles
        for role in Role.createDefaultRoles() {
            try await role.save(on: database)
        }
    }

    public func revert(on database: Database) async throws {
        try await Role.query(on: database)
            .filter(\.$isSystem == true)
            .delete()
    }
} 
