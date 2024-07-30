/**
 Middleware that performs role-based access control (RBAC) by checking the permissions of the authenticated user.

 The `RBACMiddleware` struct implements the `AsyncMiddleware` protocol and provides a way to enforce permission checks on routes. It takes a `PermissionCheck` enum as a parameter to define the type of permission check to perform.

 The `PermissionCheck` enum has three cases:
 - `all`: Requires all specified permissions to be present in the user's permissions.
 - `any`: Requires any of the specified permissions to be present in the user's permissions.
 - `custom`: Allows for a custom check function to be provided.

 The `RBACMiddleware` struct has an initializer that takes a `PermissionCheck` parameter and assigns it to the `permissionCheck` property.

 The `respond(to:chainingTo:)` method is the main entry point of the middleware. It checks if the user is authenticated and retrieves the user's role permissions from the database. It then performs the permission check based on the `permissionCheck` property and throws an `Abort` error if the user does not have the required permissions. If the permission check passes, it calls the `respond(to:)` method of the next middleware in the chain.

 The `RoutesBuilder` extension provides convenience methods for grouping routes with different permission requirements. These methods create a new instance of `RBACMiddleware` with the appropriate `PermissionCheck` case and call the `grouped(_:)` method of `RoutesBuilder` to add the middleware to the route group.

**/
import Vapor

// MARK: - Permission
/// `PermissionCheck` enum to define the type of permission check to perform.
enum PermissionCheck {
    case all([Permission])
    case any([Permission])
    case custom(([Permission]) -> Bool)
}

/// Middleware that performs role-based access control (RBAC) by checking the permissions of the authenticated user.
struct RBACMiddleware: AsyncMiddleware, @unchecked Sendable {
    
    /// The permission check to perform.
    let permissionCheck: PermissionCheck
    
    init(_ check: PermissionCheck) {
        self.permissionCheck = check
    }
    
    
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        
        guard let user = request.auth.get(User.self) else {
            throw Abort(.unauthorized, reason: "User not authenticated")
        }

        // Fetch the user's role permissions from the database
        let userRolePermissions = try await user.$rolePermissions.get(on: request.db)

        // Extract the permissions from the role permissions
        let userPermissions = Set(userRolePermissions.flatMap { $0.permissions })
        
        let hasRequiredPermissions: Bool
        
        switch permissionCheck {
        case .all(let requiredPermissions):
            hasRequiredPermissions = Set(requiredPermissions).isSubset(of: userPermissions)
        case .any(let requiredPermissions):
            hasRequiredPermissions = !Set(requiredPermissions).isDisjoint(with: userPermissions)
        case .custom(let checkFunction):
            hasRequiredPermissions = checkFunction(Array(userPermissions))
        }
        
        guard hasRequiredPermissions else {
            throw Abort(.forbidden, reason: "User does not have the required permissions")
        }
        
        return try await next.respond(to: request)
    }
}

extension RoutesBuilder {
    func grouped(requireAll permissions: Permission...) -> RoutesBuilder {
        return self.grouped(RBACMiddleware(.all(permissions)))
    }
    
    func grouped(requireAny permissions: Permission...) -> RoutesBuilder {
        return self.grouped(RBACMiddleware(.any(permissions)))
    }
    
    func grouped(customCheck: @escaping ([Permission]) -> Bool) -> RoutesBuilder {
        return self.grouped(RBACMiddleware(.custom(customCheck)))
    }
}
