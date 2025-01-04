import Fluent
import Foundation
import Vapor

/// An enumeration representing the different types of permissions in the system.
public enum Permission: String, Codable, CaseIterable, Sendable {
    // Product permissions
    case createProduct = "product:create"
    case readProduct = "product:read"
    case updateProduct = "product:update"
    case deleteProduct = "product:delete"
    case manageCategories = "product:categories"
    case manageCollections = "product:collections"
    
    // Order permissions
    case createOrder = "order:create"
    case readOrder = "order:read"
    case updateOrder = "order:update"
    case deleteOrder = "order:delete"
    case manageOrderStatus = "order:status"
    case processRefunds = "order:refunds"
    
    // Customer permissions
    case createCustomer = "customer:create"
    case readCustomer = "customer:read"
    case updateCustomer = "customer:update"
    case deleteCustomer = "customer:delete"
    case viewCustomerHistory = "customer:history"
    case manageCustomerGroups = "customer:groups"
    
    // Inventory permissions
    case manageInventory = "inventory:manage"
    case viewInventory = "inventory:read"
    case adjustStock = "inventory:adjust"
    case viewStockHistory = "inventory:history"
    
    // Payment permissions
    case processPayments = "payment:process"
    case viewTransactions = "payment:view"
    case managePaymentMethods = "payment:methods"
    case handleDisputes = "payment:disputes"
    
    // Analytics permissions
    case viewSalesReports = "analytics:sales"
    case viewCustomerReports = "analytics:customers"
    case viewInventoryReports = "analytics:inventory"
    case exportReports = "analytics:export"
    
    // System permissions
    case systemAdmin = "system:admin"
    case systemAudit = "system:audit"
    case manageSettings = "system:settings"
    
    // User management permissions
    case listUsers = "user:list"
    case viewUserDetails = "user:details"
    case viewUserRoles = "user:roles"
    case manageUserStatus = "user:status"
    case viewUserDevices = "user:devices"
    
    public static var defaultCustomerPermissions: [Permission] {
        [.readProduct, .createOrder, .readOrder]
    }
    
    public static var defaultStaffPermissions: [Permission] {
        [
            // Product permissions
            .readProduct,
            // Order permissions
            .readOrder, .updateOrder, .manageOrderStatus,
            // Customer permissions
            .readCustomer,
            // Inventory permissions
            .viewInventory,
            // Payment permissions
            .viewTransactions,
            // Analytics permissions
            .viewSalesReports,
            // User management permissions
            .listUsers,
            .viewUserDetails,
            .viewUserRoles,
            .viewUserDevices
        ]
    }
    
    public static var managerPermissions: [Permission] {
        [
            // Product permissions
            .createProduct, .readProduct, .updateProduct, .manageCategories, .manageCollections,
            // Order permissions
            .createOrder, .readOrder, .updateOrder, .manageOrderStatus, .processRefunds,
            // Customer permissions
            .createCustomer, .readCustomer, .updateCustomer, .viewCustomerHistory,
            // Inventory permissions
            .manageInventory, .viewInventory, .adjustStock, .viewStockHistory,
            // Payment permissions
            .processPayments, .viewTransactions, .managePaymentMethods,
            // Analytics permissions
            .viewSalesReports, .viewCustomerReports, .viewInventoryReports, .exportReports,
            // User management permissions
            .listUsers,
            .viewUserDetails,
            .viewUserRoles,
            .manageUserStatus,
            .viewUserDevices
        ]
    }
    
    public static var adminPermissions: [Permission] {
        Self.allCases.filter { $0 != .systemAdmin }
    }
}

/// A model representing a role in the system with associated permissions
public final class Role: Model, Content, @unchecked Sendable {
    public static let schema = "roles"
    
    @ID(key: .id)
    public var id: UUID?
    
    @Field(key: FieldKeys.name)
    public var name: String
    
    @Field(key: FieldKeys.description)
    public var description: String
    
    @Field(key: FieldKeys.permissions)
    public var permissions: [Permission]
    
    @Field(key: FieldKeys.isSystem)
    public var isSystem: Bool
    
    @Siblings(through: UserRole.self, from: \.$role, to: \.$user)
    public var users: [User]
    
    public init() { }
    
    public init(
        id: UUID? = nil,
        name: String,
        description: String,
        permissions: [Permission],
        isSystem: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.permissions = permissions
        self.isSystem = isSystem
    }
}

extension Role {
    public struct FieldKeys {
        public static let name: FieldKey = "name"
        public static let description: FieldKey = "description"
        public static let permissions: FieldKey = "permissions"
        public static let isSystem: FieldKey = "is_system"
    }
}

extension Role {
    /// Data transfer object for role information
    public struct DTO: Content, Sendable {
        public let id: UUID?
        public let name: String
        public let description: String
        public let permissions: [Permission]
        public let isSystem: Bool
    }
    
    /// Converts the role model to a DTO
    public func toDTO() -> DTO {
        return DTO(
            id: id,
            name: name,
            description: description,
            permissions: permissions,
            isSystem: isSystem
        )
    }
}

/// Pivot model for many-to-many relationship between User and Role
public final class UserRole: Model, @unchecked Sendable {
    public static let schema = "user_roles"
    
    @ID(key: .id)
    public var id: UUID?
    
    @Parent(key: FieldKeys.userId)
    public var user: User
    
    @Parent(key: FieldKeys.roleId)
    public var role: Role
    
    @Timestamp(key: FieldKeys.createdAt, on: .create)
    public var createdAt: Date?
    
    public init() { }
    
    public init(id: UUID? = nil, user: User, role: Role) throws {
        self.id = id
        self.$user.id = try user.requireID()
        self.$role.id = try role.requireID()
    }
    
    public struct FieldKeys {
        public static let userId: FieldKey = "user_id"
        public static let roleId: FieldKey = "role_id"
        public static let createdAt: FieldKey = "created_at"
    }
}

/// Extension to provide default system roles
extension Role {
    public static func createDefaultRoles() -> [Role] {
        return [
            Role(
                name: "System Admin",
                description: "Full system access with all permissions",
                permissions: Permission.allCases,
                isSystem: true
            ),
            Role(
                name: "Store Manager",
                description: "Manages store operations and staff",
                permissions: Permission.managerPermissions,
                isSystem: true
            ),
            Role(
                name: "Staff",
                description: "Regular store staff member",
                permissions: Permission.defaultStaffPermissions,
                isSystem: true
            ),
            Role(
                name: "Customer",
                description: "Regular customer account",
                permissions: Permission.defaultCustomerPermissions,
                isSystem: true
            )
        ]
    }
}