import Fluent
import Vapor

func routes(_ app: Application) throws {
    app.get { req async throws in
        try await req.view.render("index", ["title": "Hello Vapor!"])
    }

    app.get("hello") { req async -> String in
        "Hello, world!"
    }
    
    try app.register(collection: AuthenicationController())
    try app.register(collection: OrderController())
    try app.register(collection: ProductControllerV1())
    try app.register(collection: SettlementController())
    try app.register(collection: TransactionController())
    try app.register(collection: CertificateController())
    try app.register(collection: S3Controller())
    
}
