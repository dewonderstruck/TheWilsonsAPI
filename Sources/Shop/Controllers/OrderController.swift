import Vapor
import Fluent
import Auth

public struct OrderController: RouteCollection {
    public init() {}
    public func boot(routes: RoutesBuilder) throws {
        let orders = routes.grouped("orders")
        
        // All order routes require authentication
        let protected = orders.grouped(AuthMiddleware())
        
        // Customer routes (requires authentication)
        protected.post(use: create)
        protected.get("user", use: getUserOrders)
        protected.get(":orderId", use: show)
        
        // Admin/Manager routes (requires order management permissions)
        let orderManagerProtected = protected.grouped(PermissionMiddleware([
            Permission.readOrder,
            Permission.updateOrder,
            Permission.manageOrderStatus,
            Permission.processRefunds
        ]))
        orderManagerProtected.get(use: index)
        orderManagerProtected.put(":orderId", "status", use: updateStatus)
    }
    
    // List all orders (admin/manager only)
    func index(req: Request) async throws -> [OrderResponseDTO] {
        let orders = try await Order.query(on: req.db).all()
        return try orders.map { try OrderResponseDTO(from: $0) }
    }
    
    // Get a specific order
    func show(req: Request) async throws -> OrderResponseDTO {
        let user = try await req.auth.require(User.self)
        guard let order = try await Order.find(req.parameters.get("orderId"), on: req.db) else {
            throw Abort(.notFound)
        }
        
        // Get user's roles and their permissions
        let roles = try await user.$roles.get(on: req.db)
        let hasReadPermission = roles.contains { $0.permissions.contains(Permission.readOrder) }
        
        // Only allow users with read permission or order owner to view the order
        guard hasReadPermission || order.$user.id == user.id else {
            throw Abort(.forbidden)
        }
        
        return try OrderResponseDTO(from: order)
    }
    
    // Create a new order
    func create(req: Request) async throws -> OrderResponseDTO {
        let user = try await req.auth.require(User.self)
        let dto = try req.content.decode(CreateOrderDTO.self)
        
        // Verify product exists and is active
        guard let product = try await Product.find(dto.productId, on: req.db),
              product.isActive else {
            throw Abort(.notFound, reason: "Product not found or inactive")
        }
        
        // Get store's currency
        let store = try await product.$store.get(on: req.db)
        guard let price = product.pricing[store.currency] else {
            throw Abort(.badRequest, reason: "Product price not available in store currency")
        }
        
        let order = Order(
            userId: user.id!,
            productId: dto.productId,
            status: "pending",
            totalAmount: price,  // Using store's currency price
            measurements: dto.measurements,
            customizations: dto.customizations,
            selectedFabric: dto.selectedFabric,
            selectedColor: dto.selectedColor,
            shippingAddress: dto.shippingAddress,
            specialInstructions: dto.specialInstructions
        )
        
        try await order.save(on: req.db)
        return try OrderResponseDTO(from: order)
    }
    
    // Update order status (admin/manager only)
    func updateStatus(req: Request) async throws -> OrderResponseDTO {
        guard let order = try await Order.find(req.parameters.get("orderId"), on: req.db) else {
            throw Abort(.notFound)
        }
        
        let status = try req.content.decode(String.self)
        order.status = status
        
        try await order.save(on: req.db)
        return try OrderResponseDTO(from: order)
    }
    
    // Get orders for the authenticated user
    func getUserOrders(req: Request) async throws -> [OrderResponseDTO] {
        let user = try await req.auth.require(User.self)
        let orders = try await Order.query(on: req.db)
            .filter(\.$user.$id == user.id!)
            .all()
        
        return try orders.map { try OrderResponseDTO(from: $0) }
    }
} 
