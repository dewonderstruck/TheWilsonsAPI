import Vapor
import Fluent

public struct DeviceController: RouteCollection {
    public init() {}
    
    public func boot(routes: RoutesBuilder) throws {
        let devices = routes.grouped("devices")
        let protected = devices.grouped(AuthMiddleware())
        
        // Protected routes that require viewUserDevices permission
        let authorized = protected.grouped(PermissionMiddleware([.viewUserDevices]))
        
        // Device management routes
        authorized.get("users", ":userId", use: listUserDevices)
        authorized.delete("users", ":userId", ":deviceId", use: revokeUserDevice)
        authorized.post("users", ":userId", "revoke-all", use: revokeAllUserDevices)
    }
    
    // MARK: - Device Management
    
    /// List all active devices for a specific user
    private func listUserDevices(req: Request) async throws -> [Token.DTO] {
        guard let userId = req.parameters.get("userId", as: String.self) else {
            throw Abort(.badRequest, reason: "Invalid user ID")
        }
        
        // Verify user exists
        guard let _ = try await User.find(userId, on: req.authDB) else {
            throw Abort(.notFound, reason: "User not found")
        }
        
        let tokens = try await Token.listUserDevices(userId: userId, on: req.authDB)
        return tokens.map { Token.DTO(token: $0) }
    }
    
    /// Revoke a specific device for a user
    private func revokeUserDevice(req: Request) async throws -> Response {
        guard let userId = req.parameters.get("userId", as: String.self) else {
            throw Abort(.badRequest, reason: "Invalid user ID")
        }
        
        guard let deviceId = req.parameters.get("deviceId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid device ID")
        }
        
        // Verify user exists
        guard let _ = try await User.find(userId, on: req.authDB) else {
            throw Abort(.notFound, reason: "User not found")
        }
        
        try await Token.revokeToken(id: deviceId, userId: userId, on: req.authDB)
        return Response(status: .noContent)
    }
    
    /// Revoke all devices for a user except their current device
    private func revokeAllUserDevices(req: Request) async throws -> Response {
        guard let userId = req.parameters.get("userId", as: String.self) else {
            throw Abort(.badRequest, reason: "Invalid user ID")
        }
        
        // Verify user exists
        guard let _ = try await User.find(userId, on: req.authDB) else {
            throw Abort(.notFound, reason: "User not found")
        }
        
        // Get current token ID if it belongs to the target user
        let currentToken = try req.auth.require(JWTToken.self)
        
        // Only preserve current token if request is for the authenticated user
        let tokenToPreserve = currentToken.sub.value == userId ? try await Token.query(on: req.authDB)
            .filter(\.$jti == currentToken.jti)
            .first()?
            .id : nil
        
        try await Token.revokeAllTokens(userId: userId, except: tokenToPreserve, on: req.authDB)
        return Response(status: .noContent)
    }
}
