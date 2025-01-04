import Vapor
import JWT

public struct AuthMiddleware: AsyncMiddleware {
    public init() {}
    
    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        guard let bearer = request.headers.bearerAuthorization else {
            throw Abort(.unauthorized, reason: "Missing authorization header")
        }
        
        // Verify and decode the JWT token
        let token = try request.jwt.verify(bearer.token, as: JWTToken.self)
        
        // Check if token is blacklisted
        let isBlacklisted = try await token.isBlacklisted(on: request.authDB)
        guard !isBlacklisted else {
            throw Abort(.unauthorized, reason: "Token has been revoked")
        }
        
        // Store the token in the request for later use
        request.auth.login(token)
        
        return try await next.respond(to: request)
    }
}

public struct PermissionMiddleware: AsyncMiddleware {
    public let requiredPermissions: [Permission]
    
    public init(_ permissions: [Permission]) {
        self.requiredPermissions = permissions
    }
    
    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        guard let token = request.auth.get(JWTToken.self) else {
            throw Abort(.unauthorized)
        }
        
        // Check if the token has all required permissions
        let hasAllPermissions = requiredPermissions.allSatisfy { requiredPermission in
            token.scopes.contains(requiredPermission)
        }
        
        guard hasAllPermissions else {
            throw Abort(.forbidden, reason: "Insufficient permissions")
        }
        
        return try await next.respond(to: request)
    }
}

// Extension to make it easier to protect routes
public extension RoutesBuilder {
    func protected() -> RoutesBuilder {
        self.grouped(AuthMiddleware())
    }
    
    func permissioned(_ permissions: Permission...) -> RoutesBuilder {
        self.grouped([
            AuthMiddleware(),
            PermissionMiddleware(permissions)
        ])
    }
}
