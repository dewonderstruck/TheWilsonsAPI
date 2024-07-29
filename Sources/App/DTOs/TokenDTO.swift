import Vapor
import Fluent

struct TokenDTO: Content, Sendable {
    var accessToken: String
    var refreshToken: String?
    var expiresAt: Date?
    var expiresAtTimestamp: TimeInterval?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAtTimestamp = "expires"
    }
    
    func convertToPublic() -> TokenDTO {
        return self
    }
    
    @Sendable
    func toModel() -> Token {
        let model = Token()
        model.tokenValue = self.accessToken
        model.hashedRefreshToken = self.refreshToken
        model.expiresAt = self.expiresAt
        model.expiresAtTimestamp = self.expiresAtTimestamp
        return model
    }
}
