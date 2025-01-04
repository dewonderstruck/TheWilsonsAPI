import Vapor
import Fluent
import FluentMongoDriver

public extension DatabaseID {
    static var auth: DatabaseID { .init(string: "auth") }
    static var app: DatabaseID { .init(string: "app") }
}

public extension Request {
    var authDB: Database {
        db(.auth)
    }
    
    var appDB: Database {
        db(.app)
    }
} 


public func configureAuthDatabase(_ app: Application) throws {
    // MARK: - Database Configuration
    // Configure MongoDB for Auth
    try app.databases.use(.mongo(
        connectionString: Environment.get("AUTH_DATABASE_URL") ?? "mongodb://localhost:27017/wilsons-authdb"
    ), as: .auth)

    // Configure migrations for auth database
    app.migrations.add(CreateUser(), to: .auth)
    app.migrations.add(CreateRole(), to: .auth)
    app.migrations.add(CreateUserRole(), to: .auth)
    app.migrations.add(CreateBlacklistedToken(), to: .auth)
    app.migrations.add(SeedDefaultRoles(), to: .auth)

    if app.environment == .development {
        app.migrations.add(SeedTestUser(), to: .auth)
    }

        app.migrations.add(CreateCreatedAt(), to: .auth)

    // Schedule cleanup of expired blacklisted tokens every hour
    app.queues.schedule(BlacklistedTokenCleanup())
        .hourly()
        .at(.init(integerLiteral: 0))  // At minute 0 of every hour
    
}   
