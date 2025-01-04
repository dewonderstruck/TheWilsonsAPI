import Fluent
import Vapor

public struct SeedTestUser: AsyncMigration {
    public init() {}
    
    public func shouldRun(on database: Database) async throws -> Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    public func prepare(on database: Database) async throws {
        guard try await shouldRun(on: database) else { return }
        
        // Fetch roles first to generate appropriate IDs
        guard let systemAdminRole = try await Role.query(on: database)
            .filter(\.$name == "System Admin")
            .first() else {
            throw Abort(.internalServerError, reason: "System Admin role not found")
        }
        
        // Create System Admin with admin ID
        let systemAdmin = User(
            id: User.generateID(for: systemAdminRole),
            email: "admin@store.com",
            passwordHash: try Bcrypt.hash("systemadmin"),
            firstName: "System",
            lastName: "Admin",
            status: .active,
            provider: .local,
            emailVerified: true,
            phoneNumber: "+1234567890",
            phoneNumberVerified: true
        )
        try await systemAdmin.save(on: database)
        
        // Fetch other roles
        guard let managerRole = try await Role.query(on: database)
            .filter(\.$name == "Store Manager")
            .first(),
            let staffRole = try await Role.query(on: database)
            .filter(\.$name == "Staff")
            .first(),
            let customerRole = try await Role.query(on: database)
            .filter(\.$name == "Customer")
            .first() else {
            throw Abort(.internalServerError, reason: "Required roles not found")
        }
        
        // Create Store Manager
        let manager = User(
            id: User.generateID(for: managerRole),
            email: "manager@store.com",
            passwordHash: try Bcrypt.hash("manager"),
            firstName: "Store",
            lastName: "Manager",
            status: .active,
            provider: .local,
            emailVerified: true,
            phoneNumber: "+1234567891",
            phoneNumberVerified: true
        )
        try await manager.save(on: database)
        
        // Create Staff Member
        let staff = User(
            id: User.generateID(for: staffRole),
            email: "staff@store.com",
            passwordHash: try Bcrypt.hash("staff"),
            firstName: "Store",
            lastName: "Staff",
            status: .active,
            provider: .local,
            emailVerified: true,
            phoneNumberVerified: true
        )
        try await staff.save(on: database)
        
        // Create Test Customer
        let customer = User(
            id: User.generateID(for: customerRole),
            email: "customer@example.com",
            passwordHash: try Bcrypt.hash("customer"),
            firstName: "Test",
            lastName: "Customer",
            status: .active,
            provider: .local,
            emailVerified: true,
            phoneNumberVerified: false
        )
        try await customer.save(on: database)
        
        // Assign roles
        try await systemAdmin.$roles.attach(systemAdminRole, on: database)
        try await manager.$roles.attach(managerRole, on: database)
        try await staff.$roles.attach(staffRole, on: database)
        try await customer.$roles.attach(customerRole, on: database)
    }
    
    public func revert(on database: Database) async throws {
        guard try await shouldRun(on: database) else { return }
        
        // Remove test users
        try await User.query(on: database)
            .filter(\.$email ~~ ["admin@store.com", "manager@store.com", 
                                "staff@store.com", "customer@example.com"])
            .delete()
    }
} 
