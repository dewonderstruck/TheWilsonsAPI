import Fluent
import Vapor
import struct Foundation.UUID

enum Permission: String, Codable, CaseIterable {

    // MARK: - Users Permissions
    case createUsers = "users:create"
    case readUsers = "users:read"
    case updateUsers = "users:update"
    case deleteUsers = "users:delete"
    case manageUsers = "users:manage"

    // MARK: - Roles Permissions
    case createRoles = "roles:create"
    case readRoles = "roles:read"
    case updateRoles = "roles:update"
    case deleteRoles = "roles:delete"
    case manageRoles = "roles:manage"

    // MARK: - Orders Permissions
    case createOrders = "orders:create"
    case readOrders = "orders:read"
    case updateOrders = "orders:update"
    case deleteOrders = "orders:delete"
    case manageOrders = "orders:manage"

    // MARK: - Products Permissions
    case createProducts = "products:create"
    case readProducts = "products:read"
    case updateProducts = "products:update"
    case deleteProducts = "products:delete"
    case manageProducts = "products:manage"

    // MARK: - Categories Permissions
    case createCategories = "categories:create"
    case readCategories = "categories:read"
    case updateCategories = "categories:update"
    case deleteCategories = "categories:delete"

}
