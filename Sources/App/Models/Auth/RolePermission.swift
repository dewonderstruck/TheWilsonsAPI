import Fluent
import Vapor 

final class RolePermission: Model, Content, @unchecked Sendable {
    static let schema = "role_permissions"
    static let database: DatabaseID = .main
    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Field(key: "permissions")
    var permissions: [Permission]

    @Siblings(through: UserRolePermission.self, from: \.$rolePermission, to: \.$user)
    var users: [User]

    init() { }

    init(id: UUID? = nil, name: String, permissions: [Permission]) {
        self.id = id
        self.name = name
        self.permissions = permissions
    }
}
