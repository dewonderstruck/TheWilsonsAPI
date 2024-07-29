import Vapor
import Fluent


struct SeedRolePermission: AsyncMigration {
    func prepare(on database: Database) async throws {
        let role = RolePermission(
            id: UUID("A69F641E-96AE-4A4B-B6E5-2326C61D1081"),
            name: "admin",
            permissions: [
                .createUsers,
                .deleteUsers,
                .manageUsers,
                .createOrders,
                .deleteOrders,
                .manageOrders,
                .createProducts,
                .deleteProducts,
                .manageProducts
                
            ]
        )
        try await role.save(on: database)
    }

    func revert(on database: Database) async throws {
        try await RolePermission.query(on: database).delete()
    }
}
