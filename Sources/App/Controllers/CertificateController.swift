import Vapor
import Fluent

struct CertificateController: RouteCollection {

    func boot(routes: RoutesBuilder) throws {
        let v1 = routes.grouped("v1")
        let certRoute = v1.grouped("metadata", "certificates")
        certRoute.get("list", use: fetchPublicKey)
    }

    @Sendable
    func fetchPublicKey(req: Request) async throws -> [String: String] {
        guard let key = try await Key.query(on: req.db(.keyManagement))
            .filter(\.$keyType == .publicKey)
            .first() else {
            throw Abort(.notFound)
        }
        return [key.kid: key.keyData]
    }
}
