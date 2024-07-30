import Fluent
import Vapor

func routes(_ app: Application) throws {
    app.get { req async throws in
        try await req.view.render("index", ["title": "Hello Vapor!"])
    }

    app.get("hello") { req async -> String in
        "Hello, world!"
    }
    
    try app.register(collection: AuthenicationControllerV1())
    try app.register(collection: OrderControllerV1())
    try app.register(collection: ProductControllerV1())
    try app.register(collection: SettlementControllerV1())
    try app.register(collection: TransactionControllerV1())
    try app.register(collection: CertificateController())
    
}
