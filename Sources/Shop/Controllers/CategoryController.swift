import Vapor
import Fluent
import Auth

public struct CategoryController: RouteCollection {
    public init() {}
    
    public func boot(routes: RoutesBuilder) throws {
        let categories = routes.grouped("categories")
        
        // Public routes
        categories.get(use: index)
        categories.get(":categoryId", use: show)
        categories.get("type", ":type", use: getByType)
        categories.get(":categoryId", "products", use: getCategoryProducts)
        
        // Protected routes
        let protected = categories.grouped(AuthMiddleware())
        let staffProtected = protected.grouped(PermissionMiddleware([
            Permission.manageCategories
        ]))
        
        staffProtected.post(use: create)
        staffProtected.put(":categoryId", use: update)
        staffProtected.delete(":categoryId", use: delete)
    }
    
    // List all categories with optional type filter
    func index(req: Request) async throws -> [Category] {
        var query = Category.query(on: req.db)
            .filter(\.$isActive == true)
        
        if let type = try? req.query.get(String.self, at: "type") {
            query = query.filter(\.$type == type)
        }
        
        if let parentId = try? req.query.get(String.self, at: "parentId") {
            query = query.filter(\.$parent.$id == parentId)
        }
        
        return try await query
            .sort(\.$displayOrder, .ascending)
            .all()
    }
    
    // Get categories by type
    func getByType(req: Request) async throws -> [Category] {
        guard let type = req.parameters.get("type") else {
            throw Abort(.badRequest)
        }
        
        return try await Category.query(on: req.db)
            .filter(\.$type == type)
            .filter(\.$isActive == true)
            .sort(\.$displayOrder, .ascending)
            .all()
    }
    
    // Get a specific category with its children
    func show(req: Request) async throws -> Category {
        guard let category = try await Category.find(req.parameters.get("categoryId"), on: req.db) else {
            throw Abort(.notFound)
        }
        
        // Load children
        try await category.$children.load(on: req.db)
        return category
    }
    
    // Get products in a category
    func getCategoryProducts(req: Request) async throws -> [ProductListResponseDTO] {
        guard let categoryId = req.parameters.get("categoryId") else {
            throw Abort(.badRequest)
        }
        
        // First, verify the category exists
        guard let category = try await Category.find(categoryId, on: req.db) else {
            throw Abort(.notFound)
        }
        
        // Load products through the pivot
        try await category.$products.load(on: req.db)
        let products = category.products.filter { $0.isActive }
        
        return products.map { ProductListResponseDTO(from: $0) }
    }
    
    // Create a new category
    func create(req: Request) async throws -> Category {
        let category = try req.content.decode(Category.self)
        try await category.save(on: req.db)
        return category
    }
    
    // Update a category
    func update(req: Request) async throws -> Category {
        guard let category = try await Category.find(req.parameters.get("categoryId"), on: req.db) else {
            throw Abort(.notFound)
        }
        
        let updated = try req.content.decode(Category.self)
        
        category.name = updated.name
        category.slug = updated.slug
        category.description = updated.description
        category.$parent.id = updated.$parent.id
        category.metadata = updated.metadata
        category.displayOrder = updated.displayOrder
        category.type = updated.type
        category.imageUrl = updated.imageUrl
        category.isActive = updated.isActive
        
        try await category.save(on: req.db)
        return category
    }
    
    // Soft delete a category
    func delete(req: Request) async throws -> HTTPStatus {
        guard let category = try await Category.find(req.parameters.get("categoryId"), on: req.db) else {
            throw Abort(.notFound)
        }
        
        category.isActive = false
        try await category.save(on: req.db)
        return .ok
    }
} 