@testable import App
import XCTVapor
import Fluent

final class AppTests: XCTestCase, @unchecked Sendable {
    var app: Application!
    
    override func setUp() async throws {
        self.app = try await Application.make(.testing)
        try await configure(self.app)
    }
    
    override func tearDown() async throws {
        try await app.asyncShutdown()
    }
    
    func testLogin() async throws {
        let loginData = LoginData(email: "vamsi@dewonderstruck.com", password: "password")
        try await app.test(.POST, "v1/auth/login", beforeRequest: { req in
            try req.content.encode(loginData)
            req.headers.contentType = .json
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let tokenDTO = try res.content.decode(TokenDTO.self)
            XCTAssertNotNil(tokenDTO.accessToken)
            XCTAssertNotNil(tokenDTO.refreshToken)
            XCTAssertNotEqual(tokenDTO.expiresAtTimestamp, 0)
        })
    }

    func testGetCertificatesList() async throws {
        try await app.test(.GET, "hello", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
        })
    }
}
