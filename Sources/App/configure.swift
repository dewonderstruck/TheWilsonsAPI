import NIOSSL
import Fluent
import FluentMongoDriver
import Leaf
import JWT
import Vapor
import FirebaseApp
import Resend

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

     try configureDatabases(app)
     app.databases.default(to: .main)

     let corsOrigins = Environment.get("CORS_ORIGINS")?.split(separator: ",").map(String.init) ?? []
    
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .any(corsOrigins),
        allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent, .accessControlAllowOrigin, .accessControlAllowHeaders, .init("X-CSRF-TOKEN")],
        allowCredentials: true
    )
    let cors = CORSMiddleware(configuration: corsConfiguration)
    app.middleware.use(cors, at: .beginning)
    
    func loadServiceAccount(from jsonFile: String) throws -> ServiceAccount {
        let path = app.directory.resourcesDirectory.appending(jsonFile).appending(".json")
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
            let decoder = JSONDecoder()
            let serviceAccount = try decoder.decode(ServiceAccount.self, from: data)
            return serviceAccount
        } catch {
            throw NSError(domain: "JSONParsingError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Error parsing JSON file: \(error)"])
        }
    }
    
    let serviceAccount = try loadServiceAccount(from: "serviceAccount")
    FirebaseApp.initialize(serviceAccount: serviceAccount)
    
    app.sessions.use(.fluent)
    app.middleware.use(app.sessions.middleware)
    
    app.config.publicURL = Environment.get("PUBLIC_URL") ?? "http://localhost:8080"
    
    app.views.use(.leaf)
    
    app.migrations.add(CreateKey())
    app.migrations.add(CreateRolePermission())
    app.migrations.add(CreateUser())
    app.migrations.add(CreateUserRolePermission())
    app.migrations.add(CreateToken())
    app.migrations.add(SeedKeys())
    app.migrations.add(SeedUser())
    app.migrations.add(SeedRolePermission())
    app.migrations.add(SeedUserRolePermission())
    
    // Load keys from database
    let keys = try await Key.query(on: app.db).filter(\.$status == .active).all()
    
    for key in keys {
        guard let keyData = key.keyData.data(using: .utf8) else {
            throw Abort(.internalServerError, reason: "Invalid key data for key ID \(key.kid).")
        }
        switch key.keyType {
        case .privateKey:
            let privateKey = try ES256PrivateKey(pem: String(data: keyData, encoding: .utf8)!)
            await app.jwt.keys.add(ecdsa: privateKey, kid: JWKIdentifier(string: key.kid))
        case .publicKey:
            let publicKey = try ES256PublicKey(pem: String(data: keyData, encoding: .utf8)!)
            await app.jwt.keys.add(ecdsa: publicKey, kid: JWKIdentifier(string: key.kid))
        }
    }
    
    try await app.autoMigrate().get()
    
    // register routes
    try routes(app)
}
