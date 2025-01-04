import Vapor
import BSON
import Fluent
import JWT
@preconcurrency import JWTKit
import Foundation

/// A controller that handles authentication and user management endpoints.
///
/// The `AuthController` provides endpoints for:
/// - User authentication (login, signup)
/// - Password management
/// - Email verification
/// - Device management
/// - User profile management
/// - OAuth provider linking
public struct AuthController: RouteCollection {
    public init() {}
    
    /// Configures and registers all authentication routes.
    /// - Parameter routes: The routes builder to register the authentication routes with.
    /// - Throws: An error if route registration fails.
    public func boot(routes: RoutesBuilder) throws {
        let auth = routes.grouped("auth")
        
        // Public routes
        auth.post("login", use: login)
        auth.post("token", use: token)
        auth.post("signup", use: signup)
        auth.get("verify-email", use: verifyEmail)
        auth.post("resend-verification", use: resendVerification)
        auth.post("forgot-password", use: forgotPassword)
        auth.post("reset-password", use: resetPassword)
        
        // Protected routes
        let protected = auth.protected()
        protected.get("me", use: me)
        protected.post("logout", use: logout)
        protected.post("change-password", use: changePassword)
        
        // Device management routes
        protected.get("devices", use: listDevices)
        protected.delete("devices", ":id", use: revokeDevice)
        protected.post("devices/revoke-all", use: revokeAllDevices)
        
        // User management routes
        protected.get("users", use: listUsers)
        protected.get("users", ":id", use: getUser)
        
        // Add new provider linking routes
        protected.post("link-provider", use: linkProvider)
        protected.post("unlink-provider", use: unlinkProvider)
        protected.get("linked-providers", use: getLinkedProviders)
    }
    
    // MARK: - Device Management
    
    /// Lists all active devices for the authenticated user.
    ///
    /// This endpoint returns a list of all devices (tokens) that are currently active for the user.
    /// Each device entry includes information such as the device name, last used date, and IP address.
    ///
    /// - Parameter req: The incoming request containing the authenticated user's token.
    /// - Returns: An array of `Token.DTO` representing the user's active devices.
    /// - Throws: An error if the user ID is invalid or if database operations fail.
    private func listDevices(req: Request) async throws -> [Token.DTO] {
        let token = try req.auth.require(JWTToken.self)
        let userId = token.sub.value
        let tokens = try await Token.listUserDevices(userId: userId, on: req.authDB)
        return tokens.map { Token.DTO(token: $0) }
    }
    
    /// Revokes access for a specific device.
    ///
    /// This endpoint invalidates the token associated with the specified device ID,
    /// effectively logging out that device.
    ///
    /// - Parameter req: The incoming request containing the device ID to revoke.
    /// - Returns: An empty response with a 204 status code on success.
    /// - Throws: An error if the device ID is invalid or if revocation fails.
    private func revokeDevice(req: Request) async throws -> Response {
        let token = try req.auth.require(JWTToken.self)
        let userId = token.sub.value

        guard let deviceId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        try await Token.revokeToken(id: deviceId, userId: userId, on: req.authDB)
        return Response(status: .noContent)
    }
    
    /// Revokes all devices except the current one.
    ///
    /// This endpoint invalidates all tokens associated with the user except for the
    /// token used to make this request. This is useful for logging out all other sessions.
    ///
    /// - Parameter req: The incoming request from the device to preserve.
    /// - Returns: An empty response with a 204 status code on success.
    /// - Throws: An error if token revocation fails.
    private func revokeAllDevices(req: Request) async throws -> Response {
        let token = try req.auth.require(JWTToken.self)
        let userId = token.sub.value
        
        // Get current token
        let currentToken = try await Token.query(on: req.authDB)
            .filter(\.$jti == token.jti)
            .first()
        
        // Revoke all tokens except current
        try await Token.revokeAllTokens(
            userId: userId,
            except: currentToken?.id,
            on: req.authDB
        )
        
        return Response(status: .noContent)
    }
    
    // MARK: - Authentication Endpoints
    
    /// Authenticates a user with email and password.
    ///
    /// This endpoint validates the user's credentials and returns a JWT token for
    /// subsequent authenticated requests.
    ///
    /// - Parameter req: The incoming request containing login credentials.
    /// - Returns: A ``JWTToken.AuthResponse`` containing the authentication token and user information.
    /// - Throws: An error if authentication fails or credentials are invalid.
    private func login(req: Request) async throws -> JWTToken.AuthResponse {
        try LoginRequest.validate(content: req)
        let login = try req.content.decode(LoginRequest.self)
        
        guard let user = try await User.query(on: req.authDB)
            .filter(\.$email == login.email)
            .with(\.$roles)
            .first() else {
            throw Abort(.unauthorized, reason: "Invalid credentials")
        }
        
        guard try Bcrypt.verify(login.password, created: user.passwordHash) else {
            throw Abort(.unauthorized, reason: "Invalid credentials")
        }
        
        // Update last login info
        user.lastLoginAt = Date()
        user.lastLoginIp = req.remoteAddress?.hostname
        try await user.save(on: req.authDB)
        
        return try await JWTToken.generateTokens(for: user, roles: user.roles, on: req)
    }
    
    /// OAuth2-like token endpoint for refresh tokens and token info
    private func token(req: Request) async throws -> Response {
        try TokenRequest.validate(content: req)
        let tokenRequest = try req.content.decode(TokenRequest.self)
        
        req.logger.debug("Token request: \(tokenRequest)")
        
        switch tokenRequest.grantType {
        case .refreshToken:
            guard let refreshToken = tokenRequest.refreshToken else {
                throw Abort(.badRequest, reason: "Refresh token is required")
            }
            return try await handleRefreshToken(refreshToken, on: req)
            
        case .tokenInfo:
            guard let accessToken = tokenRequest.accessToken else {
                throw Abort(.badRequest, reason: "Access token is required")
            }
            return try await handleTokenInfo(accessToken, on: req)
            
        case .idToken:
            guard let idToken = tokenRequest.idToken else {
                throw Abort(.badRequest, reason: "ID token is required")
            }
            req.logger.debug("Processing ID token grant type")
            return try await handleIdToken(idToken, on: req)
        }
    }
    
    /// Handle refresh token grant type
    private func handleRefreshToken(_ refreshToken: String, on req: Request) async throws -> Response {
        // Verify refresh token
        let token = try req.jwt.verify(refreshToken, as: JWTToken.self)
        
        // Check if token exists in database
        guard let storedToken = try await Token.query(on: req.authDB)
            .filter(\.$jti == token.jti)
            .filter(\.$type == .refresh)
            .first() else {
            throw Abort(.unauthorized, reason: "Invalid refresh token")
        }
        let userId = token.sub.value
        // Get user and roles
        guard let user = try await User.query(on: req.authDB)
            .filter(\.$id == userId)
            .with(\.$roles)
            .first() else {
            throw Abort(.unauthorized, reason: "Invalid refresh token")
        }
        
        // Generate new tokens
        let tokens = try await JWTToken.generateTokens(for: user, roles: user.roles, on: req)
        
        // Delete old refresh token
        try await storedToken.delete(on: req.authDB)
        
        return try await tokens.encodeResponse(for: req)
    }
    
    /// Handle token info grant type
    private func handleTokenInfo(_ accessToken: String, on req: Request) async throws -> Response {
        // Verify access token
        let token = try req.jwt.verify(accessToken, as: JWTToken.self)
        
        let userId = token.sub.value
        
        // Get user info
        guard let user = try await User.query(on: req.authDB)
            .filter(\.$id == userId)
            .with(\.$roles)
            .first() else {
            throw Abort(.unauthorized, reason: "Invalid access token")
        }
        
        // Return token info
        let tokenInfo = TokenInfo(
            sub: token.sub.value,
            scopes: token.scopes,
            exp: token.exp.value,
            iat: token.iat.value,
            user: user.toDTO()
        )
        
        return try await tokenInfo.encodeResponse(for: req)
    }
    
    /// Register new user
    private func signup(req: Request) async throws -> Response {
        try SignupRequest.validate(content: req)
        let signup = try req.content.decode(SignupRequest.self)
        
        // Check email uniqueness
        try await User.ensureUniqueness(forEmail: signup.email, on: req.authDB)
        
        // Create user
        let hashedPassword = try Bcrypt.hash(signup.password)
        let user = User(
            email: signup.email,
            passwordHash: hashedPassword,
            firstName: signup.firstName,
            lastName: signup.lastName,
            status: .active,
            provider: .local,
            emailVerified: false,
            phoneNumberVerified: false
        )
        try await user.save(on: req.authDB)
        
        // Assign default member role
        guard let memberRole = try await Role.query(on: req.authDB)
            .filter(\.$name == "Member")
            .first() else {
            throw Abort(.internalServerError, reason: "Default role not found")
        }
        try await user.$roles.attach(memberRole, on: req.authDB)
        
        // Generate verification token
        let verificationToken = try generateVerificationToken(for: user, on: req)
        
        // Send verification email
        try await req.emailService.sendVerificationEmail(
            to: user.email,
            name: user.firstName,
            token: verificationToken
        )
        
        // Send welcome email
        try await req.emailService.sendWelcomeEmail(
            to: user.email,
            name: user.firstName
        )
        
        return Response(status: .created)
    }
    
    /// Verify email address
    private func verifyEmail(req: Request) async throws -> Response {
        guard let token = req.query[String.self, at: "token"] else {
            throw Abort(.badRequest, reason: "Verification token is required")
        }
        
        // Verify token
        let verifiedToken = try req.jwt.verify(token, as: EmailVerificationToken.self)
        let userId = verifiedToken.sub.value
        guard let user = try await User.find(userId, on: req.authDB) else {
            throw Abort(.notFound, reason: "User not found")
        }
        
        // Update user's email verification status
        user.emailVerified = true
        try await user.save(on: req.authDB)
        
        return Response(status: .ok)
    }
    
    /// Resend verification email
    private func resendVerification(req: Request) async throws -> Response {
        try ResendVerificationRequest.validate(content: req)
        let resend = try req.content.decode(ResendVerificationRequest.self)
        
        guard let user = try await User.query(on: req.authDB)
            .filter(\.$email == resend.email)
            .first() else {
            throw Abort(.notFound, reason: "User not found")
        }
        
        guard !user.emailVerified else {
            throw Abort(.badRequest, reason: "Email is already verified")
        }
        
        // Generate new verification token
        let verificationToken = try generateVerificationToken(for: user, on: req)
        
        // Send verification email
        try await req.emailService.sendVerificationEmail(
            to: user.email,
            name: user.firstName,
            token: verificationToken
        )
        
        return Response(status: .ok)
    }
    
    /// Request password reset
    private func forgotPassword(req: Request) async throws -> Response {
        try ForgotPasswordRequest.validate(content: req)
        let forgot = try req.content.decode(ForgotPasswordRequest.self)
        
        guard let user = try await User.query(on: req.authDB)
            .filter(\.$email == forgot.email)
            .first() else {
            // Return OK even if user not found for security
            return Response(status: .ok)
        }
        
        // Generate password reset token
        let resetToken = try generatePasswordResetToken(for: user, on: req)
        
        // Send password reset email
        try await req.emailService.sendPasswordResetEmail(
            to: user.email,
            name: user.firstName,
            token: resetToken
        )
        
        return Response(status: .ok)
    }
    
    /// Reset password using token
    private func resetPassword(req: Request) async throws -> Response {
        try ResetPasswordRequest.validate(content: req)
        let reset = try req.content.decode(ResetPasswordRequest.self)
        
        // Verify token
        let verifiedToken = try req.jwt.verify(reset.token, as: PasswordResetToken.self)
        let userId = verifiedToken.sub.value
        guard let user = try await User.find(userId, on: req.authDB) else {
            throw Abort(.notFound, reason: "User not found")
        }
        
        // Update password
        user.passwordHash = try Bcrypt.hash(reset.newPassword)
        try await user.save(on: req.authDB)
        
        return Response(status: .ok)
    }
    
    /// Get current user profile
    private func me(req: Request) async throws -> User.DTO {
        let token = try req.auth.require(JWTToken.self)
        let userId = token.sub.value
        // Load user with roles relationship
        guard let user = try await User.query(on: req.authDB)
            .filter(\.$id == userId)
            .with(\.$roles)
            .first() else {
            throw Abort(.notFound)
        }
        
        // Convert to DTO with roles included
        var dto = user.toDTO()
        dto.roles = user.roles.map { $0.toDTO() }
        
        return dto
    }
    
    /// Logout (revoke tokens)
    private func logout(req: Request) async throws -> Response {
        let token = try req.auth.require(JWTToken.self)
        
        // Blacklist the current access token
        try await token.blacklist(on: req.authDB)
        
        // If refresh token is provided, blacklist it too
        if let refreshTokenString = try? req.content.get(String.self, at: "refresh_token") {
            let refreshToken = try req.jwt.verify(refreshTokenString, as: JWTToken.self)
            try await refreshToken.blacklist(on: req.authDB)
        }
        
        let userId = token.sub.value
        
        // Update user's validSince timestamp to invalidate all previous tokens
        guard let user = try await User.find(userId, on: req.authDB) else {
            throw Abort(.notFound)
        }
        
        // Set validSince to current time
        user.validSince = Date()
        try await user.save(on: req.authDB)
        
        // Clean up expired blacklisted tokens
        try await BlacklistedToken.query(on: req.authDB)
            .filter(\.$expiresAt < Date())
            .delete()
        
        return Response(status: .noContent)
    }
    
    /// Change password
    private func changePassword(req: Request) async throws -> Response {
        try ChangePasswordRequest.validate(content: req)
        let changePass = try req.content.decode(ChangePasswordRequest.self)
        
        let token = try req.auth.require(JWTToken.self)
        let userId = token.sub.value
        
        guard let user = try await User.query(on: req.authDB)
            .filter(\.$id == userId)
            .first() else {
            throw Abort(.notFound)
        }
        
        // Verify current password
        guard try Bcrypt.verify(changePass.currentPassword, created: user.passwordHash) else {
            throw Abort(.unauthorized, reason: "Invalid current password")
        }
        
        // Update password
        user.passwordHash = try Bcrypt.hash(changePass.newPassword)
        try await user.save(on: req.authDB)
        
        return Response(status: .noContent)
    }
    
    // MARK: - User Management
    
    /// List users with filters and pagination
    private func listUsers(req: Request) async throws -> UserListResponse {
        let token = try req.auth.require(JWTToken.self)

        let userId = token.sub.value
        
        guard let requester = try await User.find(userId, on: req.authDB) else {
            throw Abort(.unauthorized)
        }
        
        let filters = try req.query.decode(UserListFilters.self)
        let userService = UserService(db: req.authDB)
        return try await userService.listUsers(filters: filters, requester: requester)
    }
    
    /// Get user by ID
    private func getUser(req: Request) async throws -> User.DTO {
        let token = try req.auth.require(JWTToken.self)

        let userId = token.sub.value
        
        guard let requester = try await User.find(userId, on: req.authDB) else {
            throw Abort(.unauthorized)
        }
        
        guard let targetUserId = req.parameters.get("id", as: String.self) else {
            throw Abort(.badRequest)
        }
        
        let userService = UserService(db: req.authDB)
        return try await userService.getUser(id: targetUserId, requester: requester)
    }
    
    // MARK: - Helper Methods
    
    private func generateVerificationToken(for user: User, on req: Request) throws -> String {
        
        guard let userId = user.id else {
            throw Abort(.internalServerError)
        }
        
        let token = EmailVerificationToken(
            subject: userId,
            expirationTime: 86400 // 24 hours
        )
        
        return try req.jwt.sign(token)
    }
    
    private func generatePasswordResetToken(for user: User, on req: Request) throws -> String {
        guard let userId = user.id else {
            throw Abort(.internalServerError)
        }
        
        let token = PasswordResetToken(
            subject: userId,
            expirationTime: 3600 // 1 hour
        )
        
        return try req.jwt.sign(token)
    }
    
    /// Handle ID token authentication and account linking
    private func handleIdToken(_ idToken: String, on req: Request) async throws -> Response {
        // Decode and verify the ID token based on provider
        let (provider, payload) = try await verifyIdToken(idToken, on: req)
        
        // Extract email and provider user info from token payload
        guard let email = payload.email,
              !email.isEmpty else {
            throw Abort(.badRequest, reason: "Email not found in ID token")
        }
        
        // Check if user exists with this email
        let existingUser = try await User.query(on: req.authDB)
            .filter(\.$email == email)
            .with(\.$roles)
            .first()
        
        if let existingUser = existingUser {
            // User exists - handle account linking or login
            return try await handleExistingUser(
                existingUser,
                provider: provider,
                payload: payload,
                on: req
            )
        } else {
            // New user - create account and return tokens
            return try await handleNewUser(
                email: email,
                provider: provider,
                payload: payload,
                on: req
            )
        }
    }
    
    /// Verify and decode ID token based on provider
    private func verifyIdToken(_ idToken: String, on req: Request) async throws -> (Provider, SocialTokenPayload) {
        req.logger.debug("Raw ID token: \(idToken)")
        
        // First, decode the token without verification to get the issuer
        let parts = idToken.components(separatedBy: ".")
        guard parts.count == 3,
              let payloadData = Data(base64Encoded: parts[1].padding(toLength: ((parts[1].count + 3) / 4) * 4,
                                                                     withPad: "=",
                                                                     startingAt: 0)),
              let payload = try? JSONDecoder().decode(GenericJWT.self, from: payloadData) else {
            throw Abort(.badRequest, reason: "Invalid token format")
        }
        
        req.logger.debug("Decoded issuer: \(payload.iss.value)")
        
        // Based on issuer, verify with appropriate provider
        switch payload.iss.value {
        case "https://accounts.google.com":
            req.logger.debug("Processing as Google token")
            let verifiedPayload = try await verifyGoogleIdToken(idToken, on: req)
            return (.google, verifiedPayload)
            
        case "https://appleid.apple.com":
            req.logger.debug("Processing as Apple token")
            let verifiedPayload = try await verifyAppleIdToken(idToken, on: req)
            return (.apple, verifiedPayload)
            
        default:
            req.logger.error("Unsupported provider issuer: \(payload.iss.value)")
            throw Abort(.badRequest, reason: "Unsupported ID token provider")
        }
    }
    
    /// Handle existing user authentication/linking
    private func handleExistingUser(
        _ user: User,
        provider: Provider,
        payload: SocialTokenPayload,
        on req: Request
    ) async throws -> Response {
        // Check if this provider is already linked
        if let existingProvider = user.linkedProviders.first(where: { $0.provider == provider }) {
            // Update provider info
            user.linkedProviders.removeAll { $0.provider == provider }
            user.linkedProviders.append(LinkedProvider(
                provider: provider,
                providerId: payload.sub,
                email: payload.email,
                displayName: payload.name,
                photoUrl: payload.picture
            ))
            try await user.save(on: req.authDB)
            
            let tokens = try await JWTToken.generateTokens(
                for: user,
                roles: user.roles,
                on: req
            )
            
            return try await AuthResponse(
                tokens: tokens,
                isNewUser: false
            ).encodeResponse(for: req)
        } else if user.provider == provider {
            let linkedProvider = LinkedProvider(
                provider: provider,
                providerId: payload.sub,
                email: payload.email,
                displayName: payload.name,
                photoUrl: payload.picture
            )
            // Update or add linked provider
            if let index = user.linkedProviders.firstIndex(where: { $0.provider == provider }) {
                user.linkedProviders[index] = linkedProvider
            } else {
                user.linkedProviders.append(linkedProvider)
            }
            
            try await user.save(on: req.authDB)
            
            let tokens = try await JWTToken.generateTokens(
                for: user,
                roles: user.roles,
                on: req
            )
            
            return try await AuthResponse(
                tokens: tokens,
                isNewUser: false
            ).encodeResponse(for: req)
            
        } else if !user.linkedProviders.contains(where: { $0.provider == provider && $0.providerId == payload.sub }) {
            // If user exists but was not created with Google and provider not linked
            throw Abort(.unauthorized, reason: "Provider not linked. Use /auth/link-provider to link this provider.")
        }
        
        // Provider not linked - throw error suggesting to use link endpoint
        throw Abort(.unauthorized, reason: "Provider not linked. Use /auth/link-provider to link this provider.")
    }
    
    /// Handle new user registration
    private func handleNewUser(
        email: String,
        provider: Provider,
        payload: SocialTokenPayload,
        on req: Request
    ) async throws -> Response {
        // Create new user
        let user = User(
            email: email,
            passwordHash: "", // Empty for social providers
            firstName: payload.givenName,
            lastName: payload.familyName,
            status: .active,
            provider: provider,
            providerInfo: ProviderUserInfo(
                providerId: payload.sub,
                displayName: payload.name,
                photoUrl: payload.picture,
                email: payload.email
            ),
            emailVerified: true, // Email is verified by provider
            phoneNumberVerified: false
        )
        
        try await user.save(on: req.authDB)
        
        // Assign default member role
        guard let memberRole = try await Role.query(on: req.authDB)
            .filter(\.$name == "Member")
            .first() else {
            throw Abort(.internalServerError, reason: "Default role not found")
        }
        
        try await user.$roles.attach(memberRole, on: req.authDB)
        
        // Generate tokens
        let tokens = try await JWTToken.generateTokens(
            for: user,
            roles: [memberRole],
            on: req
        )
        
        // Return response with isNewUser flag
        return try await AuthResponse(
            tokens: tokens,
            isNewUser: true
        ).encodeResponse(for: req)
    }
    
    /// Verify Google ID token
    private func verifyGoogleIdToken(_ idToken: String, on req: Request) async throws -> SocialTokenPayload {
        req.logger.debug("Starting Google token verification")
        
        // Get Google's public keys from their JWKS endpoint
        let jwksURL = "https://www.googleapis.com/oauth2/v3/certs"
        req.logger.debug("Fetching Google JWKS from: \(jwksURL)")
        
        let response = try await req.client.get(URI(string: jwksURL))
        req.logger.debug("JWKS response status: \(response.status.code)")
        
        // Parse the JWKS response
        struct GoogleJWKS: Content, Sendable {
            let keys: [JWK]
        }
        
        let jwks = try response.content.decode(GoogleJWKS.self)
        req.logger.debug("Decoded JWKS with \(jwks.keys.count) keys")
        
        // Create JWT signers from Google's public keys
        let signers = JWTSigners()
        for key in jwks.keys {
            try signers.use(jwk: key)
        }
        
        do {
            // Verify and decode the token
            let payload = try signers.verify(idToken, as: SocialTokenPayload.self)
            
            // Validate Google-specific claims
            guard let clientId = Environment.get("GOOGLE_CLIENT_ID") else {
                req.logger.error("GOOGLE_CLIENT_ID environment variable not set")
                throw Abort(.internalServerError, reason: "Missing Google configuration")
            }
            
            req.logger.debug("Validating token audience: \(payload.aud)")
            guard payload.aud == clientId else {
                req.logger.error("Token audience mismatch. Expected: \(clientId), Got: \(payload.aud)")
                throw Abort(.unauthorized, reason: "Invalid audience")
            }
            
            req.logger.debug("Google token verification successful")
            return payload
            
        } catch {
            req.logger.error("Google token verification failed: \(error)")
            throw Abort(.unauthorized, reason: "Invalid Google token: \(error.localizedDescription)")
        }
    }
    
    /// Verify Apple ID token
    private func verifyAppleIdToken(_ idToken: String, on req: Request) async throws -> SocialTokenPayload {
        req.logger.debug("Starting Apple token verification")
        
        // Get Apple's public keys from their JWKS endpoint
        let jwksURL = "https://appleid.apple.com/auth/keys"
        req.logger.debug("Fetching Apple JWKS from: \(jwksURL)")
        
        let response = try await req.client.get(URI(string: jwksURL))
        req.logger.debug("JWKS response status: \(response.status.code)")
        
        let jwks = try response.content.decode(JWKS.self)
        req.logger.debug("Decoded JWKS with \(jwks.keys.count) keys")
        
        // Create JWT signers from Apple's public keys
        let signers = JWTSigners()
        try jwks.keys.forEach { key in
            try signers.use(jwk: key)
        }
        
        // Verify token
        req.logger.debug("Attempting to verify token with Apple public keys")
        let payload = try signers.verify(idToken, as: SocialTokenPayload.self)
        
        // Validate Apple-specific claims
        guard let clientId = Environment.get("APPLE_CLIENT_ID") else {
            req.logger.error("APPLE_CLIENT_ID environment variable not set")
            throw Abort(.internalServerError, reason: "Missing Apple configuration")
        }
        
        req.logger.debug("Validating token audience: \(payload.aud)")
        guard payload.aud == clientId else {
            req.logger.error("Token audience mismatch. Expected: \(clientId), Got: \(payload.aud)")
            throw Abort(.unauthorized, reason: "Invalid audience")
        }
        
        req.logger.debug("Validating token issuer: \(payload.iss)")
        guard payload.iss == "https://appleid.apple.com" else {
            req.logger.error("Token issuer mismatch. Got: \(payload.iss)")
            throw Abort(.unauthorized, reason: "Invalid issuer")
        }
        
        req.logger.debug("Apple token verification successful")
        return payload
    }
    
    // MARK: - Provider Linking
    
    /// Link a new provider to the current account
    private func linkProvider(req: Request) async throws -> Response {
        try LinkProviderRequest.validate(content: req)
        let linkRequest = try req.content.decode(LinkProviderRequest.self)
        
        // Get current user
        let token = try req.auth.require(JWTToken.self)
        let userId = token.sub.value
        guard let user = try await User.find(userId, on: req.authDB) else {
            throw Abort(.unauthorized)
        }
        
        // Verify and decode the ID token
        let (provider, payload) = try await verifyIdToken(linkRequest.idToken, on: req)
        
        // Ensure email matches if present
        if let tokenEmail = payload.email,
           !tokenEmail.isEmpty,
           tokenEmail.lowercased() != user.email.lowercased() {
            throw Abort(.badRequest, reason: "Email mismatch")
        }
        
        // Check if provider is already linked
        if user.linkedProviders.contains(where: { $0.provider == provider }) {
            throw Abort(.badRequest, reason: "Provider already linked")
        }
        
        // Check if another account has this provider ID
        let queryDocument = Document(arrayLiteral: [
            "linkedProviders": [
                "$elemMatch": [
                    "providerId": payload.sub
                ]
            ]
        ])
        
        if try await User.query(on: req.authDB)
            .filter(\.$id != userId)
            .filter(.custom(queryDocument))
            .first() != nil {
            throw Abort(.conflict, reason: "Provider already linked to another account")
        }
        
        // Add new linked provider
        let linkedProvider = LinkedProvider(
            provider: provider,
            providerId: payload.sub,
            email: payload.email,
            displayName: payload.name,
            photoUrl: payload.picture
        )
        
        user.linkedProviders.append(linkedProvider)
        try await user.save(on: req.authDB)
        
        return Response(status: .ok)
    }
    
    /// Unlink a provider from the current account
    private func unlinkProvider(req: Request) async throws -> Response {
        try UnlinkProviderRequest.validate(content: req)
        let unlinkRequest = try req.content.decode(UnlinkProviderRequest.self)
        
        // Get current user
        let token = try req.auth.require(JWTToken.self)
        let userId = token.sub.value
        
        guard let user = try await User.find(userId, on: req.authDB) else {
            throw Abort(.unauthorized)
        }
        
        // Ensure at least one provider remains
        guard user.linkedProviders.count > 1 || user.provider == .local else {
            throw Abort(.badRequest, reason: "Cannot remove last authentication method")
        }
        
        // Remove the provider
        user.linkedProviders.removeAll { $0.provider == unlinkRequest.provider }
        try await user.save(on: req.authDB)
        
        return Response(status: .ok)
    }
    
    /// Get all linked providers for the current user
    private func getLinkedProviders(req: Request) async throws -> LinkedProvidersResponse {
        let token = try req.auth.require(JWTToken.self)
        let userId = token.sub.value
        
        guard let user = try await User.find(userId, on: req.authDB) else {
            throw Abort(.unauthorized)
        }
        
        return LinkedProvidersResponse(
            primaryProvider: user.provider,
            linkedProviders: user.linkedProviders
        )
    }
}

// MARK: - Request/Response DTOs
private extension AuthController {
    enum GrantType: String, Codable {
        case refreshToken = "refresh_token"
        case tokenInfo = "token_info"
        case idToken = "id_token"
    }
    
    struct TokenRequest: Content, Validatable {
        let grantType: GrantType
        let refreshToken: String?
        let accessToken: String?
        let idToken: String?
        
        enum CodingKeys: String, CodingKey {
            case grantType = "grant_type"
            case refreshToken = "refresh_token"
            case accessToken = "access_token"
            case idToken = "id_token"
        }
        
        static func validations(_ validations: inout Validations) {
            validations.add("grant_type", as: String.self, is: .in("refresh_token", "token_info", "id_token"))
        }
    }
    
    struct TokenInfo: Content {
        let sub: String
        let scopes: [Permission]
        let exp: Date
        let iat: Date
        let user: User.DTO
    }
    
    struct LoginRequest: Content, Validatable {
        let email: String
        let password: String
        
        static func validations(_ validations: inout Validations) {
            validations.add("email", as: String.self, is: .email)
            validations.add("password", as: String.self, is: .count(3...))
        }
    }
    
    struct SignupRequest: Content, Validatable {
        let email: String
        let password: String
        let firstName: String?
        let lastName: String?
        
        static func validations(_ validations: inout Validations) {
            validations.add("email", as: String.self, is: .email)
            validations.add("password", as: String.self, is: .count(6...))
            validations.add("firstName", as: String?.self, is: .nil || .count(1...50))
            validations.add("lastName", as: String?.self, is: .nil || .count(1...50))
        }
    }
    
    struct RefreshRequest: Content, Validatable {
        let refreshToken: String
        
        static func validations(_ validations: inout Validations) {
            validations.add("refreshToken", as: String.self, is: !.empty)
        }
    }
    
    struct ChangePasswordRequest: Content, Validatable {
        let currentPassword: String
        let newPassword: String
        
        static func validations(_ validations: inout Validations) {
            validations.add("currentPassword", as: String.self, is: !.empty)
            validations.add("newPassword", as: String.self, is: .count(6...))
        }
    }
    
    struct ResendVerificationRequest: Content, Validatable {
        let email: String
        
        static func validations(_ validations: inout Validations) {
            validations.add("email", as: String.self, is: .email)
        }
    }
    
    struct ForgotPasswordRequest: Content, Validatable {
        let email: String
        
        static func validations(_ validations: inout Validations) {
            validations.add("email", as: String.self, is: .email)
        }
    }
    
    struct ResetPasswordRequest: Content, Validatable {
        let token: String
        let newPassword: String
        
        static func validations(_ validations: inout Validations) {
            validations.add("token", as: String.self, is: !.empty)
            validations.add("newPassword", as: String.self, is: .count(6...))
        }
    }
    
    struct LinkProviderRequest: Content, Validatable {
        let idToken: String
        
        static func validations(_ validations: inout Validations) {
            validations.add("idToken", as: String.self, is: !.empty)
        }
    }
    
    struct UnlinkProviderRequest: Content, Validatable {
        let provider: Provider
        
        static func validations(_ validations: inout Validations) {
            validations.add("provider", as: String.self, is: .in(
                Provider.google.rawValue,
                Provider.apple.rawValue,
                Provider.facebook.rawValue
            ))
        }
    }
    
    struct LinkedProvidersResponse: Content, Sendable{
        let primaryProvider: Provider
        let linkedProviders: [LinkedProvider]
    }
}

// MARK: - Token Types
struct EmailVerificationToken: JWTPayload {
    var sub: SubjectClaim
    var exp: ExpirationClaim
    var iat: IssuedAtClaim
    
    init(subject: String, expirationTime: TimeInterval) {
        self.sub = SubjectClaim(value: subject)
        self.exp = ExpirationClaim(value: Date().addingTimeInterval(expirationTime))
        self.iat = IssuedAtClaim(value: Date())
    }
    
    func verify(using signer: JWTSigner) throws {
        try exp.verifyNotExpired()
    }
}

struct PasswordResetToken: JWTPayload {
    var sub: SubjectClaim
    var exp: ExpirationClaim
    var iat: IssuedAtClaim
    
    init(subject: String, expirationTime: TimeInterval) {
        self.sub = SubjectClaim(value: subject)
        self.exp = ExpirationClaim(value: Date().addingTimeInterval(expirationTime))
        self.iat = IssuedAtClaim(value: Date())
    }
    
    func verify(using signer: JWTSigner) throws {
        try exp.verifyNotExpired()
    }
}

// MARK: - Social Token Payload
private struct SocialTokenPayload: JWTPayload {
    let iss: String
    let sub: String
    let aud: String
    let exp: Date
    let iat: Date
    let email: String?
    let emailVerified: Bool?
    let name: String?
    let givenName: String?
    let familyName: String?
    let picture: String?
    
    enum CodingKeys: String, CodingKey {
        case iss, sub, aud, exp, iat
        case email
        case emailVerified = "email_verified"
        case name
        case givenName = "given_name"
        case familyName = "family_name"
        case picture
    }
    
    // Required by JWTPayload protocol
    func verify(using signer: JWTSigner) throws {
        // Verify expiration
        guard Date() < exp else {
            throw JWTError.claimVerificationFailure(name: "exp", reason: "Token has expired")
        }
        
        // Verify issued at
        guard Date() >= iat else {
            throw JWTError.claimVerificationFailure(name: "iat", reason: "Token used before issued")
        }
    }
}

// MARK: - Auth Response
private struct AuthResponse: Content {
    let accessToken: String
    let refreshToken: String
    let expiresIn: TimeInterval
    let tokenType: String
    let isNewUser: Bool
    
    init(tokens: JWTToken.AuthResponse, isNewUser: Bool) {
        self.accessToken = tokens.accessToken
        self.refreshToken = tokens.refreshToken
        self.expiresIn = tokens.expiresIn
        self.tokenType = tokens.tokenType
        self.isNewUser = isNewUser
    }
}

// Add this helper struct for initial JWT verification
private struct GenericJWT: JWTPayload {
    let iss: IssuerClaim
    let sub: SubjectClaim?
    let aud: AudienceClaim?
    let exp: ExpirationClaim?
    let iat: IssuedAtClaim?
    
    func verify(using signer: JWTSigner) throws {
        // Basic verification of expiration if present
        try exp?.verifyNotExpired()
    }
}
