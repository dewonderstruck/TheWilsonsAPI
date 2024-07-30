import Vapor
import Fluent

// Function to configure databases
func configureDatabases(_ app: Application) throws {

    // MARK: - MongoDB BaseURL
    // mongodb://<username>:<password>@<hostname>:<port>/<database>
    guard let mongoDBURL = Environment.get("MONGODB_URL") else {
        app.logger.critical("MongoDB URL not found in environment variables.")
        throw Abort(.internalServerError, reason: "MongoDB configuration failed.")
    }

    // MARK: - Main Database
    let mainDB = mongoDBURL + "/main"
    let productsDB = mongoDBURL + "/products"
    let ordersDB = mongoDBURL + "/orders"
    let transactionsDB = mongoDBURL + "/transactions"
    let settlementsDB = mongoDBURL + "/settlements"
    let keyManagementDB = mongoDBURL + "/keyManagement"

    // MARK: - Attach Databases
    try app.databases.use(.mongo(connectionString: productsDB), as: .products)
    try app.databases.use(.mongo(connectionString: mainDB), as: .main)
    try app.databases.use(.mongo(connectionString: ordersDB), as: .orders)
    try app.databases.use(.mongo(connectionString: transactionsDB), as: .transactions)
    try app.databases.use(.mongo(connectionString: settlementsDB), as: .settlements)
    try app.databases.use(.mongo(connectionString: keyManagementDB), as: .keyManagement)
    
}

extension DatabaseID {
    static let main = DatabaseID(string: "main")
    static let products = DatabaseID(string: "products")
    static let orders = DatabaseID(string: "orders")
    static let transactions = DatabaseID(string: "transactions")
    static let settlements = DatabaseID(string: "settlements")
    static let tokens = DatabaseID(string: "tokens")
    static let keyManagement = DatabaseID(string: "keyManagement")
}
