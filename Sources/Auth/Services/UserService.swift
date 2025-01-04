import Fluent
import Vapor

// Update UserListFilters to explicitly conform to Sendable
public struct UserListFilters: Content, Sendable {
    public var status: UserStatus?
    public var provider: Provider?
    public var emailVerified: Bool?
    public var phoneVerified: Bool?
    public var roleId: UUID?
    public var search: String?
    public var page: Int?
    public var per: Int?
    
    public init(
        status: UserStatus? = nil,
        provider: Provider? = nil,
        emailVerified: Bool? = nil,
        phoneVerified: Bool? = nil,
        roleId: UUID? = nil,
        search: String? = nil,
        page: Int? = 1,
        per: Int? = 10
    ) {
        self.status = status
        self.provider = provider
        self.emailVerified = emailVerified
        self.phoneVerified = phoneVerified
        self.roleId = roleId
        self.search = search
        self.page = page
        self.per = per
    }
}

// Make PageMetadata Sendable
extension UserListResponse.PageMetadata: Sendable {}

public struct UserListResponse: Content, Sendable {
    public let users: [User.DTO]
    public let metadata: PageMetadata
    
    public struct PageMetadata: Content {
        public let page: Int
        public let per: Int
        public let total: Int
        public let pageCount: Int
    }
}

public struct UserService {
    public let db: Database
    
    public init(db: Database) {
        self.db = db
    }
    
    public func listUsers(
        filters: UserListFilters,
        requester: User
    ) async throws -> UserListResponse {
        // Check if user has permission to list users
        guard try await hasPermission(user: requester, permission: .listUsers) else {
            throw Abort(.forbidden, reason: "Insufficient permissions to list users")
        }
        
        let page = filters.page ?? 1
        let per = min(filters.per ?? 10, 100) // Cap at 100 items per page
        
        var query = User.query(on: db)
        
        // Only load roles if user has permission to view them
        let canViewRoles = try await hasPermission(user: requester, permission: .viewUserRoles)
        if canViewRoles {
            query = query.with(\.$roles)
        }
        
        // Apply filters
        if let status = filters.status {
            // Check if user has permission to filter by status
            guard try await hasPermission(user: requester, permission: .manageUserStatus) else {
                throw Abort(.forbidden, reason: "Insufficient permissions to filter by user status")
            }
            query = query.filter(\.$status == status)
        }
        
        if let provider = filters.provider {
            query = query.filter(\.$provider == provider)
        }
        
        if let emailVerified = filters.emailVerified {
            query = query.filter(\.$emailVerified == emailVerified)
        }
        
        if let phoneVerified = filters.phoneVerified {
            query = query.filter(\.$phoneNumberVerified == phoneVerified)
        }
        
        if let roleId = filters.roleId {
            // Check if user has permission to filter by role
            guard try await hasPermission(user: requester, permission: .viewUserRoles) else {
                throw Abort(.forbidden, reason: "Insufficient permissions to filter by role")
            }
            query = query.join(UserRole.self, on: \User.$id == \UserRole.$user.$id)
                .filter(UserRole.self, \.$role.$id == roleId)
        }
        
        // Apply search if provided
        if let search = filters.search?.trimmingCharacters(in: .whitespacesAndNewlines),
           !search.isEmpty {
            query = query.group(.or) { group in
                group.filter(\.$email ~~ search)
                    .filter(\.$firstName ~~ search)
                    .filter(\.$lastName ~~ search)
                    .filter(\.$phoneNumber ~~ search)
            }
        }
        
        // Get total count for pagination
        let total = try await query.count()
        
        // Apply pagination
        let users = try await query
            .sort(\.$email, .ascending)
            .paginate(PageRequest(page: page, per: per))
            .items
        
        let pageCount = Int(ceil(Double(total) / Double(per)))
        
        return UserListResponse(
            users: users.map { user in
                var dto = user.toDTO()
                if canViewRoles {
                    dto.roles = user.roles.map { $0.toDTO() }
                }
                return dto
            },
            metadata: .init(
                page: page,
                per: per,
                total: total,
                pageCount: pageCount
            )
        )
    }
    
    public func getUser(
        id: String,
        requester: User
    ) async throws -> User.DTO {
        // Check if user has permission to view user details
        guard try await hasPermission(user: requester, permission: .viewUserDetails) else {
            throw Abort(.forbidden, reason: "Insufficient permissions to view user details")
        }
        
        guard let user = try await User.query(on: db)
            .filter(\.$id == id)
            .with(\.$roles)
            .first() else {
            throw Abort(.notFound, reason: "User not found")
        }
        
        var dto = user.toDTO()
        
        // Only include roles if user has permission to view them
        if try await hasPermission(user: requester, permission: .viewUserRoles) {
            dto.roles = user.roles.map { $0.toDTO() }
        }
        
        return dto
    }
    
    // Helper method to check permissions
    private func hasPermission(
        user: User,
        permission: Permission
    ) async throws -> Bool {
        try await user.$roles.load(on: db)
        return user.roles.flatMap { $0.permissions }.contains(permission)
    }
    
    // Helper method to check multiple permissions (any)
    private func hasAnyPermission(
        user: User,
        permissions: [Permission]
    ) async throws -> Bool {
        try await user.$roles.load(on: db)
        let userPermissions = user.roles.flatMap { $0.permissions }
        return permissions.contains { userPermissions.contains($0) }
    }
    
    // Helper method to check multiple permissions (all)
    private func hasAllPermissions(
        user: User,
        permissions: [Permission]
    ) async throws -> Bool {
        try await user.$roles.load(on: db)
        let userPermissions = user.roles.flatMap { $0.permissions }
        return permissions.allSatisfy { userPermissions.contains($0) }
    }
} 
