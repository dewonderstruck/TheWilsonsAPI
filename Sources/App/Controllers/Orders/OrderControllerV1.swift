import Fluent
import Vapor

struct OrderControllerV1: RouteCollection {
    
    func boot(routes: RoutesBuilder) throws {
        let v1 = routes.grouped("v1")
        let orders = v1.grouped("orders")
        // Protected routes
        let protectedOrders = orders.grouped(TokenAuthenticator()).grouped(User.guardMiddleware())
        protectedOrders.grouped(requireAll: .readOrders).get(use: index)
        protectedOrders.grouped(requireAll: .createOrders).post(use: create)
        // Require multiple permissions (AND logic)
        protectedOrders.grouped(requireAll: .updateOrders, .manageOrders).put(":orderId", use: update)
        // Require any of the specified permissions (OR logic)
        protectedOrders.grouped(requireAny: .deleteOrders, .manageOrders).delete(":orderId", use: delete)
        protectedOrders.grouped(requireAll: .readOrders).get(":orderID", use: show)
    }
    
    @Sendable
    func index(req: Request) async throws -> [OrderDTO] {
        let orders = try await Order.query(on: req.db).with(\.$items).all()
        do {
            return try orders.map { try $0.toDTO() }
        } catch {
            throw Abort(.internalServerError, reason: "Failed to convert orders to DTOs.")
        }
    }
    
    @Sendable
    func create(req: Request) async throws -> OrderDTO {
        let input = try req.content.decode(OrderDTO.self)
        let order = Order(userID: input.userID, total: input.total, status: input.status)
        try await order.save(on: req.db)
        
        for itemDTO in input.items {
            let orderItem = OrderItem(orderID: try order.requireID(), productID: itemDTO.productID, quantity: itemDTO.quantity, price: itemDTO.price)
            try await orderItem.save(on: req.db)
        }
        
        return try order.toDTO()
    }
    
    @Sendable
    func show(req: Request) async throws -> OrderDTO {
        guard let order = try await Order.find(req.parameters.get("orderID"), on: req.db) else {
            throw Abort(.notFound)
        }
        try await order.$items.load(on: req.db)
        return try order.toDTO()
    }
    
    @Sendable
    func update(req: Request) async throws -> OrderDTO {
        
        guard let order = try await Order.find(req.parameters.get("orderID"), on: req.db) else {
            throw Abort(.notFound)
        }
        
        let input = try req.content.decode(OrderDTO.self)
        order.total = input.total
        order.status = input.status
        try await order.save(on: req.db)
        
        let existingItems = try await order.$items.get(on: req.db)
        for item in existingItems {
            try await item.delete(on: req.db)
        }
        
        for itemDTO in input.items {
            let orderItem = OrderItem(orderID: try order.requireID(), productID: itemDTO.productID, quantity: itemDTO.quantity, price: itemDTO.price)
            try await orderItem.save(on: req.db)
        }
        
        return try order.toDTO()
    }
    
    
    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        guard let order = try await Order.find(req.parameters.get("orderID"), on: req.db) else {
            throw Abort(.notFound)
        }
        try await order.delete(on: req.db)
        return .noContent
    }
}
