import NIOSSL
import Fluent
import FluentMongoDriver
import Leaf
import JWT
import Vapor
import FirebaseApp

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    let ecdsaPrivateKeyPEM = try String(contentsOfFile: app.directory.workingDirectory + "ecdsa-p256-private.pem")
    let ecdsaPublicKeyPEM = try String(contentsOfFile: app.directory.workingDirectory + "ecdsa-p256-public.pem")
    
    let privateKey = try ES256PrivateKey(pem: ecdsaPrivateKeyPEM)
    let publicKey = try ES256PublicKey(pem: ecdsaPublicKeyPEM)
    
    await app.jwt.keys.add(ecdsa: privateKey, kid: "private")
    await app.jwt.keys.add(ecdsa: publicKey, kid: "public")

    try app.databases.use(DatabaseConfigurationFactory.mongo(
        connectionString: Environment.get("DATABASE_URL") ?? "mongodb+srv://app:RwTZ2blIQMBseXGg@cluster0.jbjxtbt.mongodb.net"
    ), as: .mongo)

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
    

    app.migrations.add(CreateUser())
    
    app.migrations.add(CreateToken())

    app.views.use(.leaf)

    try await app.autoMigrate().get()
    
    // register routes
    try routes(app)
}
