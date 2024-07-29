import Fluent
import Vapor

final class UserRolePermission: Model, @unchecked Sendable {
    static let schema = "user_role_permissions"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: User

    @Parent(key: "role_permission_id")
    var rolePermission: RolePermission

    init() { }

    init(id: UUID? = nil, user: User, rolePermission: RolePermission) throws {
        self.id = id
        self.$user.id = try user.requireID()
        self.$rolePermission.id = try rolePermission.requireID()
    }
}