import Fluent
import Vapor
import Foundation

struct SeedUserRolePermission: AsyncMigration {
    func prepare(on database: Database) async throws {
        
        let user = User(
            id: UUID("A69F641E-96AE-4A4B-B6E5-2326C61D1080"),
            firstName: "Vamsi",
            lastName: "Madduluri",
            email: "vamsi@dewonderstruck.com",
            password: try Bcrypt.hash("password"),
            status: .active,
            role: [.admin],
            provider: .local,
            providerUserId: nil,
            externalIdentifier: nil,
            memberId: nil,
            accountType: .user,
            emailVerified: true,
            phoneNumberVerified: false,
            phoneNumber: "1234567890",
            address: "1234 Main St",
            area: "Downtown"
        )
        
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
        let userPermission = try UserRolePermission(
            id: UUID(),
            user: user,
            rolePermission: role
        )
        try await userPermission.save(on: database)
    }

    func revert(on database: Database) async throws {
        try await UserRolePermission.query(on: database).delete()
    }
}
