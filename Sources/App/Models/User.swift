import Fluent
import Vapor
import struct Foundation.UUID

enum AccountType: String, Codable {
    case managed
    case user
    case customer
    case organization
}

enum Provider: String, Codable {
    case firebase
    case local
    case other
}

enum Status: String, Codable {
    case active
    case inactive
    case suspended
}

enum Roles: String, Codable {
    case admin
    case user
    case superAdmin
}

final class User: Model, Content, @unchecked Sendable {
    static let schema: String = "users"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "first_name")
    var firstName: String?
    
    @Field(key: "last_name")
    var lastName: String?
    
    @Field(key: "email")
    var email: String
    
    @Field(key: "password")
    var password: String
    
    @Enum(key: "status")
    var status: Status
    
    @Field(key: "role")
    var role: [Roles]
    
    @Enum(key: "provider")
    var provider: Provider
    
    @Field(key: "provider_user_id")
    var providerUserId: String?
    
    @Field(key: "external_identifier")
    var externalIdentifier: String?
    
    @Field(key: "member_id")
    var memberId: String?
    
    @Enum(key: "account_type")
    var accountType: AccountType
    
    @Field(key: "email_verified")
    var emailVerified: Bool?
    
    @Field(key: "phone_number_verified")
    var phoneNumberVerified: Bool?
    
    @Field(key: "phone_number")
    var phoneNumber: String?
    
    @Field(key: "address")
    var address: String?
    
    @Field(key: "area")
    var area: String?
    
    @Siblings(through: UserRolePermission.self, from: \.$user, to: \.$rolePermission)
    var rolePermissions: [RolePermission]
    
    init() { }
    
    init(
        id: UUID? = nil,
        firstName: String? = nil,
        lastName: String? = nil,
        email: String,
        password: String,
        status: Status? = .active,
        role: [Roles]? = [.user],
        provider: Provider? = .local,
        providerUserId: String?,
        externalIdentifier: String?,
        memberId: String? = nil,
        accountType: AccountType? = .user,
        emailVerified: Bool? = false,
        phoneNumberVerified: Bool? = false,
        phoneNumber: String? = nil,
        address: String?,
        area: String?
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.password = password
        self.status = status ?? .active
        self.role = role ?? [.user]
        self.provider = provider ?? .local
        self.providerUserId = providerUserId
        self.externalIdentifier = externalIdentifier
        self.memberId = memberId
        self.accountType = accountType ?? .user
        self.emailVerified = emailVerified
        self.phoneNumberVerified = phoneNumberVerified
        self.phoneNumber = phoneNumber
        self.address = address
        self.area = area
    }
    
    func toDTO() -> UserDTO {
        .init(
            id: self.id,
            firstName: self.firstName,
            lastName: self.lastName,
            email: self.email,
            status: self.status,
            role: self.role,
            provider: self.provider,
            providerUserId: self.providerUserId,
            externalIdentifier: self.externalIdentifier,
            memberId: self.memberId,
            accountType: self.accountType,
            emailVerified: self.emailVerified,
            phoneNumberVerified: self.phoneNumberVerified,
            phoneNumber: self.phoneNumber,
            address: self.address,
            area: self.area
        )
    }
}

extension User {
    
    static func uniqueUsername(forFirstName first: String, lastName last: String) -> String {
        return "\(first).\(last)-\(Date().timeIntervalSince1970)".lowercased()
    }
    
    static func uniqueness(forEmail email: String, on request: Request) async throws -> Bool {
        return try await !User.isExisting(matching: \.$email == email, on: request.db)
    }
    
    static func ensureUniqueness(for registrant: User, on request: Request) async throws {
        let unique = try await User.uniqueness(forEmail: registrant.email, on: request)
        guard unique else { throw Abort(.badRequest, reason: "A user with this email or username already exists") }
    }
}
