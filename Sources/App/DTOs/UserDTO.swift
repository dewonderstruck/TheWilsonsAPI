import Fluent
import Vapor

struct UserDTO: Content {
    var id: UUID?
    var firstName: String?
    var lastName: String?
    var email: String?
    var status: Status?
    var role: [Roles]?
    let provider: Provider?
    let providerUserId: String?
    var externalIdentifier: String?
    var memberId: String?
    var accountType: AccountType?
    var emailVerified: Bool?
    var phoneNumberVerified: Bool?
    var phoneNumber: String?
    var address: String?
    var area: String?
    
    func convertToPublic() -> UserDTO {
        return UserDTO(
            id: id,
            firstName: firstName,
            lastName: lastName,
            email: email,
            status: status,
            role: role,
            provider: provider, providerUserId: providerUserId,
            externalIdentifier: externalIdentifier,
            memberId: memberId,
            accountType: accountType,
            emailVerified: emailVerified,
            phoneNumberVerified: phoneNumberVerified,
            phoneNumber: phoneNumber,
            address: address,
            area: area
        )
    }
    
    func toModel() -> User {
        let model = User()
        
        model.id = self.id
        if let firstName = self.firstName {
            model.firstName = firstName
        }
        if let lastName = self.lastName {
            model.lastName = lastName
        }
        if let email = self.email {
            model.email = email
        }
        if let status = self.status {
            model.status = status
        }
        if let role = self.role {
            model.role = role
        }
        if let providerUserId = self.providerUserId {
            model.providerUserId = providerUserId
        }
        if let provider = self.provider {
            model.provider = provider
        }
        if let externalIdentifier = self.externalIdentifier {
            model.externalIdentifier = externalIdentifier
        }
        if let memberId = self.memberId {
            model.memberId = memberId
        }
        if let accountType = self.accountType, let type = AccountType(rawValue: accountType.rawValue) {
            model.accountType = type
        }
        if let emailVerified = self.emailVerified {
            model.emailVerified = emailVerified
        }
        if let phoneNumberVerified = self.phoneNumberVerified {
            model.phoneNumberVerified = phoneNumberVerified
        }
        if let phoneNumber = self.phoneNumber {
            model.phoneNumber = phoneNumber
        }
        if let address = self.address {
            model.address = address
        }
        if let area = self.area {
            model.area = area
        }
        
        return model
    }
}
