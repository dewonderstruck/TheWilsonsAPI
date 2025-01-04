import Vapor
import Auth
import Shop

func routes(_ app: Application) throws {
    // Auth routes
    try app.register(collection: AuthController())
    try app.register(collection: DeviceController())
    
    // Shop routes
    try app.register(collection: ProductController())
    try app.register(collection: OrderController())
    try app.register(collection: CategoryController())
    try app.register(collection: CustomizationController())
}
