import Foundation
import Vapor
import Fluent
import JWT
import JWTKit

struct UserPayload: JWTPayload {
    enum CodingKeys: String, CodingKey {
        case subject = "sub"
        case expiration = "exp"
        case issuedAt = "iat"
        case issuer = "iss"
        case aud = "aud"
        case scope = "scope"
        case role = "role"
    }
    let role: String
    let scope: String
    var subject: SubjectClaim
    var expiration: ExpirationClaim
    var issuedAt: IssuedAtClaim
    var issuer: IssuerClaim
    var aud: AudienceClaim?
    
    func verify(using algorithm: some JWTAlgorithm) async throws {
        try expiration.verifyNotExpired()
    }
}

extension Token: ModelTokenAuthenticatable {
    typealias User = App.User
    
    static let valueKey = \Token.$tokenValue
    static let userKey = \Token.$user
    
    var isValid: Bool {
        guard let expiresAt = expiresAt else {
            return false
        }
        return Date() < expiresAt
    }
    
    static func authenticate(
        token: String,
        for request: Request
    ) async throws -> User {
        guard let token = try await Token.query(on: request.db)
            .filter(\.$tokenValue == token)
            .first()
        else {
            throw Abort(.unauthorized)
        }
        
        guard token.isValid else {
            try await token.delete(on: request.db)
            throw Abort(.unauthorized)
        }
        return try await token.$user.get(on: request.db)
    }
}

extension Token {
    func timeUntilExpirationInMilliseconds() -> Int? {
        guard let expiresAt = self.expiresAt else { return nil }
        let currentTime = Date()
        let timeInterval = expiresAt.timeIntervalSince(currentTime)
        return timeInterval > 0 ? Int(timeInterval * 1000) : 0
    }
}
