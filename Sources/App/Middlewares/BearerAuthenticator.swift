//
//  File.swift
//  
//
//  Created by Vamsi Madduluri on 24/07/24.
//
import Vapor
import JWT

struct TokenAuthenticator: AsyncBearerAuthenticator {
    typealias User = App.User
    
    func authenticate(bearer: BearerAuthorization, for request: Request) async throws {
        guard let payload = try? await request.jwt.verify(bearer.token, as: UserPayload.self) else {
            return
        }
        
        guard let user = try await User.find(UUID(uuidString: payload.subject.value), on: request.db) else {
            return
        }
        
        request.auth.login(user)
    }
}
