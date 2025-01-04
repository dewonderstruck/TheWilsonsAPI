import Fluent
import Foundation
import Vapor
import struct Foundation.UUID

/// Authentication providers supported by the system.
///
/// The `Provider` enumeration defines the various authentication methods
/// available for user authentication in the system.
///
/// ## Topics
/// ### Available Providers
/// - ``local``
/// - ``google``
/// - ``facebook``
/// - ``apple``
public enum Provider: String, Codable, CustomStringConvertible, Sendable {
    /// Local authentication using email and password.
    ///
    /// This is the traditional authentication method where users
    /// register and login using their email and password.
    case local
    
    /// Google OAuth authentication.
    ///
    /// Allows users to sign in using their Google account.
    case google
    
    /// Facebook OAuth authentication.
    ///
    /// Allows users to sign in using their Facebook account.
    case facebook
    
    /// Apple Sign In authentication.
    ///
    /// Allows users to sign in using their Apple ID.
    case apple
    
    public var description: String { rawValue }
    
    public init?(_ description: String) {
        self.init(rawValue: description)
    }
}

/// Represents the current status of a user in the system.
///
/// The `UserStatus` enumeration defines the possible states a user account
/// can be in, which determines their ability to access the system.
///
/// ## Topics
/// ### Status Types
/// - ``active``
/// - ``inactive``
/// - ``suspended``
public enum UserStatus: String, Codable, Sendable {
    /// User is active and can access the system.
    ///
    /// This is the default state for verified users who have full access to the system.
    case active
    
    /// User is inactive and cannot access the system.
    ///
    /// This state may indicate an unverified email or a deactivated account.
    case inactive
    
    /// User is temporarily suspended.
    ///
    /// This state indicates that the user's access has been temporarily revoked,
    /// usually due to policy violations or security concerns.
    case suspended
}

/// Contains provider-specific information about a user.
///
/// The `ProviderUserInfo` struct stores authentication provider-specific
/// details about a user, such as their provider ID and profile information.
///
/// ## Topics
/// ### Properties
/// - ``providerId``
/// - ``displayName``
/// - ``photoUrl``
/// - ``email``
public struct ProviderUserInfo: Codable, Sendable {
    /// The provider's unique identifier for the user.
    ///
    /// This ID is specific to the authentication provider and remains constant
    /// for the user within that provider's system.
    public var providerId: String?
    
    /// The user's display name from the provider.
    ///
    /// This is typically the name the user has set in their provider account.
    public var displayName: String?
    
    /// URL to the user's profile photo.
    ///
    /// A link to the user's profile picture from the provider's system.
    public var photoUrl: String?
    
    /// The user's email from the provider.
    ///
    /// The email address associated with the user's account at the provider.
    public var email: String?
}

/// Represents a linked authentication provider for a user.
///
/// The `LinkedProvider` struct contains information about an authentication
/// provider that has been linked to a user's account, enabling multiple
/// sign-in methods.
///
/// ## Topics
/// ### Properties
/// - ``provider``
/// - ``providerId``
/// - ``email``
public struct LinkedProvider: Codable, Sendable {
    /// The type of authentication provider.
    public let provider: Provider
    
    /// The provider's unique identifier for the user.
    public let providerId: String
    
    /// The email associated with the provider account, if available.
    public let email: String?
    public let displayName: String?
    public let photoUrl: String?
    public let linkedAt: Date
    
    public init(
        provider: Provider,
        providerId: String,
        email: String?,
        displayName: String?,
        photoUrl: String?,
        linkedAt: Date = Date()
    ) {
        self.provider = provider
        self.providerId = providerId
        self.email = email
        self.displayName = displayName
        self.photoUrl = photoUrl
        self.linkedAt = linkedAt
    }
}

public final class User: Model, Content, Authenticatable, @unchecked Sendable {
    public static let schema = "users"
    
    @ID(custom: "id", generatedBy: .user)
    public var id: String?
    
    @Field(key: FieldKeys.email)
    public var email: String
    
    @Field(key: FieldKeys.passwordHash)
    public var passwordHash: String
    
    @Field(key: FieldKeys.firstName)
    public var firstName: String?
    
    @Field(key: FieldKeys.lastName)
    public var lastName: String?
    
    @Enum(key: FieldKeys.status)
    public var status: UserStatus
    
    @Field(key: FieldKeys.provider)
    public var provider: Provider
    
    @Field(key: FieldKeys.providerInfo)
    public var providerInfo: ProviderUserInfo?
    
    @Field(key: FieldKeys.emailVerified)
    public var emailVerified: Bool
    
    @Field(key: FieldKeys.phoneNumberVerified)
    public var phoneNumberVerified: Bool
    
    @Field(key: FieldKeys.phoneNumber)
    public var phoneNumber: String?
    
    @Field(key: FieldKeys.lastLoginAt)
    public var lastLoginAt: Date?
    
    @Field(key: FieldKeys.lastLoginIp)
    public var lastLoginIp: String?
    
    @Field(key: FieldKeys.validSince)
    public var validSince: Date?
    
    @Siblings(through: UserRole.self, from: \.$user, to: \.$role)
    public var roles: [Role]

    @Timestamp(key: FieldKeys.createdAt, on: .create)
    public var createdAt: Date?
    
    @Field(key: FieldKeys.linkedProviders)
    public var linkedProviders: [LinkedProvider]
    
    public init() { }
    
    public init(
        id: String? = nil,
        email: String,
        passwordHash: String,
        firstName: String? = nil,
        lastName: String? = nil,
        status: UserStatus = .active,
        provider: Provider = .local,
        providerInfo: ProviderUserInfo? = nil,
        emailVerified: Bool = false,
        phoneNumber: String? = nil,
        phoneNumberVerified: Bool = false,
        lastLoginAt: Date? = nil,
        lastLoginIp: String? = nil,
        validSince: Date? = nil,
        createdAt: Date? = nil,
        linkedProviders: [LinkedProvider] = []
    ) {
        self.id = id
        self.email = email
        self.passwordHash = passwordHash
        self.firstName = firstName
        self.lastName = lastName
        self.status = status
        self.provider = provider
        self.providerInfo = providerInfo
        self.emailVerified = emailVerified
        self.phoneNumber = phoneNumber
        self.phoneNumberVerified = phoneNumberVerified
        self.lastLoginAt = lastLoginAt
        self.lastLoginIp = lastLoginIp
        self.validSince = validSince
        self.createdAt = createdAt
        self.linkedProviders = linkedProviders
    }
}

extension User {
    public struct FieldKeys {
        public static let email: FieldKey = "email"
        public static let passwordHash: FieldKey = "password_hash"
        public static let firstName: FieldKey = "first_name"
        public static let lastName: FieldKey = "last_name"
        public static let status: FieldKey = "status"
        public static let provider: FieldKey = "provider"
        public static let providerInfo: FieldKey = "provider_info"
        public static let emailVerified: FieldKey = "email_verified"
        public static let phoneNumberVerified: FieldKey = "phone_number_verified"
        public static let phoneNumber: FieldKey = "phone_number"
        public static let lastLoginAt: FieldKey = "last_login_at"
        public static let lastLoginIp: FieldKey = "last_login_ip"
        public static let validSince: FieldKey = "valid_since"
        public static let createdAt: FieldKey = "created_at"
        public static let linkedProviders: FieldKey = "linked_providers"
    }
}

extension User {
    /// Data transfer object for user information
    public struct DTO: Content {
        public let id: String?
        public let email: String
        public let firstName: String?
        public let lastName: String?
        public let status: UserStatus
        public let provider: Provider
        public let providerInfo: ProviderUserInfo?
        public let lastLoginAt: Date?
        public var roles: [Role.DTO]?
        public let createdAt: Date?
        
        public init(
            id: String?,
            email: String,
            firstName: String?,
            lastName: String?,
            status: UserStatus,
            provider: Provider,
            providerInfo: ProviderUserInfo?,
            lastLoginAt: Date?,
            roles: [Role.DTO]? = nil,
            createdAt: Date?
        ) {
            self.id = id
            self.email = email
            self.firstName = firstName
            self.lastName = lastName
            self.status = status
            self.provider = provider
            self.providerInfo = providerInfo
            self.lastLoginAt = lastLoginAt
            self.roles = roles
            self.createdAt = createdAt
        }
    }
    
    /// Converts the user model to a DTO
    public func toDTO() -> DTO {
        return DTO(
            id: id,
            email: email,
            firstName: firstName,
            lastName: lastName,
            status: status,
            provider: provider,
            providerInfo: providerInfo,
            lastLoginAt: lastLoginAt,
            roles: nil,
            createdAt: createdAt
        )
    }
}

extension User {
    /// Helper methods for user management
    public static func uniqueness(forEmail email: String, on db: Database) async throws -> Bool {
        let existingUser = try await User.query(on: db)
            .filter(\.$email == email)
            .first()
        return existingUser == nil
    }
    
    public static func ensureUniqueness(forEmail email: String, on db: Database) async throws {
        guard try await uniqueness(forEmail: email, on: db) else {
            throw Abort(.badRequest, reason: "Email already exists")
        }
    }
}

extension User {
    /// Add a static method for ID generation
    public static func generateID(for role: Role) -> String {
        switch role.name {
        case "Customer":
            return IDPrefix.customer.generate()
        case "Staff":
            return IDPrefix.staff.generate()
        case "System Admin", "Store Manager":
            return IDPrefix.admin.generate()
        default:
            return IDPrefix.customer.generate()
        }
    }
}
