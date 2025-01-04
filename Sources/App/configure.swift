import NIOSSL
import Fluent
import FluentMongoDriver
import Vapor
import JWT
import Queues
import QueuesRedisDriver
import Auth
import Shop

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    app.logger.logLevel = .info

    // Configure MongoDB for App
    try app.databases.use(.mongo(
        connectionString: Environment.get("APP_DATABASE_URL") ?? "mongodb://localhost:27017/wilsons-appdb"
    ), as: .app)   

    let corsOrigins = Environment.get("CORS_ORIGINS")?.split(separator: ",").map(String.init) ?? [
        "http://localhost:8080",
        "http://localhost:3000"
    ]
    
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .any(corsOrigins),
        allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent, .accessControlAllowOrigin, .accessControlAllowHeaders, .init("X-CSRF-TOKEN")],
        allowCredentials: true
    )
    
    let cors = CORSMiddleware(configuration: corsConfiguration)
    app.middleware.use(cors, at: .beginning)

    // MARK: - JWT Configuration
    app.jwt.signers.use(.hs256(key: Environment.get("JWT_SECRET") ?? "your-super-secret-key-change-this-in-production")) 

    // Configure middleware
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))

    // MARK: - Queue Configuration
    try app.queues.use(.redis(url: Environment.get("REDIS_URL") ?? "redis://localhost:6379"))

    try configureAuthDatabase(app)
    try configureShopDatabase(app)
   
    // register routes
    try routes(app)

    // Run migrations
    try await app.autoMigrate().get()
}

func configureShopDatabase(_ app: Application) throws {
    // Add Shop migrations
    app.migrations.add(CreateStore())
    app.migrations.add(CreateCategory())
    app.migrations.add(CreateCollection())
    app.migrations.add(CreateProduct())
    app.migrations.add(CreateOrder())
    app.migrations.add(CreateProductCategory())
    app.migrations.add(CreateProductCollection())
    app.migrations.add(CreateCustomizationOption())
    
    // Add seed data
    app.migrations.add(SeedDefaultStores())
    app.migrations.add(SeedDefaultCategories())
}
