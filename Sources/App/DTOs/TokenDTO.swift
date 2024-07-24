import Vapor 
import Fluent 

struct TokenDTO: Content, Sendable {
    var accessToken: String
    var refreshToken: String?
    var expires: Date?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }

    func convertToPublic() -> TokenDTO {
        return self
    }

    @Sendable
    func toModel() -> Token {
        let model = Token()
        model.tokenValue = self.accessToken
        model.hashedRefreshToken = self.refreshToken
        model.expiresAt = self.expires
        return model
    }
}
