import Vapor
import Fluent
import FirebaseAuth

struct LoginData: Content, Authenticatable {
    let email: String
    let password: String
}

/// A controller responsible for handling authentication-related endpoints.
struct AuthenicationControllerV1: RouteCollection {
    
    /// Boots the authentication routes.
    /// - Parameter routes: The routes builder.
    func boot(routes: RoutesBuilder) throws {
        let v1 = routes.grouped("v1")
        let auth = v1.grouped("auth")
        let authGroup = auth.grouped(TokenAuthenticator()).grouped(User.guardMiddleware())
        auth.post("login", use: loginHandler)
        auth.post("refresh", use: refreshHandler)
        auth.post("login", ":provider", use: loginWithProviderHandler)
        authGroup.post("logout", use: enhancedLogoutHandler)
    }
    
     // MARK: - Login
    /// Handles the login request and returns a token.
    /// - Parameter req: The incoming request.
    /// - Returns: A `TokenDTO` containing the access token, refresh token, and expiration date.
    @Sendable
    func loginHandler(_ req: Request) async throws -> TokenDTO {
        let loginData = try req.content.decode(LoginData.self)
        
        guard let user = try await User.query(on: req.db)
            .filter(\.$email == loginData.email)
            .first()
        else {
            throw Abort(.unauthorized)
        }
        
        guard try Bcrypt.verify(loginData.password, created: user.password) else {
            throw Abort(.unauthorized)
        }
        
        // Create a new token
        let (token, refreshTokenString) = try await Token.generate(for: user, using: req)
        try await token.save(on: req.db)
        
        // Create and return TokenDTO
        return TokenDTO(
            accessToken: token.tokenValue,
            refreshToken: refreshTokenString,
            expires: token.expiresAt
        )
    }
    
    // MARK: - Refresh Token
    /// Handles the refresh token request and returns a new token.
    /// - Parameter req: The incoming request.
    /// - Returns: A `TokenDTO` containing the new access token, new refresh token, and expiration date.
    @Sendable
    func refreshHandler(_ req: Request) async throws -> TokenDTO {
        
        guard let refreshToken = try? req.content.get(String.self, at: "refresh_token") else {
            throw Abort(.badRequest, reason: "Refresh token is required")
        }
        
        let hashedRefreshToken = try Token.hashRefreshToken(refreshToken)
        
        guard let token = try await Token.query(on: req.db)
            .filter(\.$hashedRefreshToken == hashedRefreshToken)
            .filter(\.$status == .active)
            .with(\.$user)
            .first() else {
            throw Abort(.unauthorized, reason: "Invalid refresh token")
        }
        
        guard let refreshTokenExpiresAt = token.refreshTokenExpiresAt,
              refreshTokenExpiresAt > Date() else {
            token.status = .revoked
            try await token.save(on: req.db)
            throw Abort(.unauthorized, reason: "Refresh token has expired")
        }
        
        let user = token.user
        
        let (newToken, newRefreshTokenString) = try await Token.generate(for: user, using: req)
        
        try await newToken.save(on: req.db)
        
        token.status = .revoked
        try await token.save(on: req.db)
        
        return TokenDTO(
            accessToken: newToken.tokenValue,
            refreshToken: newRefreshTokenString,
            expires: newToken.expiresAt
        )
    }
    
    // MARK: - Firebase Authentication
    /// Handles the login request using a provider and returns a token.
    /// - Parameter req: The incoming request.
    /// - Returns: A `TokenDTO` containing the access token, refresh token, and expiration date.
    @Sendable
    func loginWithProviderHandler(_ req: Request) async throws -> TokenDTO {

        guard let provider = req.parameters.get("provider") else {
            throw Abort(.badRequest, reason: "Provider is required")
        }
        
        guard let idToken = try? req.content.get(String.self, at: "id_token") else {
            throw Abort(.badRequest, reason: "ID token is required")
        }
        
        let firebaseUser = try await FirebaseAuth.auth().validate(idToken: idToken)
        
        guard let email = firebaseUser.email else {
            throw Abort(.badRequest, reason: "Email is required")
        }
        
        var user = try await User.query(on: req.db)
            .filter(\.$email == email)
            .first()

        let firebaseUserFirstName = firebaseUser.name?.components(separatedBy: " ").first
        let firebaseUserLastName = firebaseUser.name?.components(separatedBy: " ").last
        
        if user == nil {
            // Create a new user
            user = User(
                firstName: firebaseUserFirstName, 
                lastName: firebaseUserLastName,
                email: email,
                password: firebaseUser.userID,
                provider: .firebase,
                providerUserId: firebaseUser.userID,
                externalIdentifier: "firebase", 
                emailVerified: firebaseUser.isEmailVerified,
                phoneNumber: firebaseUser.phoneNumber,
                address: nil,
                area: nil
            )
            try await user?.save(on: req.db)
        }
        
        guard let existingUser = user else {
            throw Abort(.unauthorized)
        }
        
        // Create a new token
        let (token, refreshTokenString) = try await Token.generate(for: existingUser, using: req)
        try await token.save(on: req.db)
        
        // Create and return TokenDTO
        return TokenDTO(
            accessToken: token.tokenValue,
            refreshToken: refreshTokenString,
            expires: token.expiresAt
        )
    }
    
    // MARK: - Enhanced Logout
    /// Handles the enhanced logout request and revokes the token.
    /// - Parameter req: The incoming request.
    /// - Returns: An `HTTPStatus` indicating the success of the logout operation.
    @Sendable
    func enhancedLogoutHandler(_ req: Request) async throws -> HTTPStatus {
        
        guard let bearer = req.headers.bearerAuthorization else {
            throw Abort(.unauthorized, reason: "Missing authorization header")
        }
        
        let accessToken = bearer.token
        
        guard let token = try await Token.query(on: req.db)
            .filter(\.$tokenValue == accessToken)
            .first() else {
            throw Abort(.notFound, reason: "Token not found")
        }
        
        guard token.status == .active else {
            throw Abort(.badRequest, reason: "Token is already revoked")
        }
        
        token.status = .revoked
        try await token.save(on: req.db)
        
        let logoutAll = req.query[Bool.self, at: "all"] ?? false
        
        if logoutAll {
            try await Token.query(on: req.db)
                .filter(\.$user.$id == token.$user.id)
                .filter(\.$status == .active)
                .filter(\.$id != token.id!)
                .set(\.$status, to: .revoked)
                .update()
        }
        
        return .ok
    }
}
