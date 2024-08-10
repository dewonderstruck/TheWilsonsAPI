import Vapor
import Fluent

/// A controller that handles operations related to certificates.
struct CertificateController: RouteCollection {

    /// Registers the routes for the `CertificateController`.
    ///
    /// - Parameter routes: The `RoutesBuilder` to register routes on.
    /// - Throws: An error if the routes cannot be registered.
    func boot(routes: RoutesBuilder) throws {
        let v1 = routes.grouped("v1")
        let certRoute = v1.grouped("metadata", "certificates")
        certRoute.get("list", use: fetchPublicKey)
    }

    /// Fetches the public key from the database.
    ///
    /// - Parameter req: The `Request` object.
    /// - Returns: A dictionary containing the key ID and the public key data.
    /// - Throws: An error if the public key cannot be found.
    @Sendable
    func fetchPublicKey(req: Request) async throws -> [String: String] {
        guard let key = try await Key.query(on: req.db)
            .filter(\.$keyType == .publicKey)
            .first() else {
            throw Abort(.notFound)
        }
        return [key.kid: key.keyData]
    }
}