import Vapor
import Fluent
import Auth
import MongoKitten

public struct ProductController: RouteCollection {
    public init() {}
    public func boot(routes: RoutesBuilder) throws {
        let products = routes.grouped("products")
        
        // Public routes
        products.get(use: index)
        products.get(":productId", use: show)
        products.get("store", ":storeId", use: getStoreProducts)
        
        // Protected routes with authentication and role-based access
        let protected = products.grouped(AuthMiddleware())
        
        // Staff routes (includes product management permissions)
        let staffProtected = protected.grouped(PermissionMiddleware([
            Permission.createProduct,
            Permission.updateProduct,
            Permission.deleteProduct,
            Permission.manageCategories
        ]))
        
        // Admin routes (system admin permissions)
        let adminProtected = protected.grouped(PermissionMiddleware([Permission.systemAdmin]))
        
        // Staff and admin routes
        staffProtected.post(use: create)
        staffProtected.put(":productId", use: update)
        staffProtected.delete(":productId", use: delete)
        
        // Store-specific routes (requires authentication)
        let storeProtected = protected.grouped("store", ":storeId")
        storeProtected.get("products", use: getStoreProducts)
    }
    
    // List all active products with optional filtering
    func index(req: Request) async throws -> [ProductListResponseDTO] {
        var query = Product.query(on: req.db)
            .filter(\.$isActive == true)
        
        // Apply filters if present
        if let category = try? req.query.get(String.self, at: "category") {
            query = query.filter(\.$category == category)
        }
        
        // For price filtering, we'll need to load all products and filter in memory
        let products = try await query
            .join(Store.self, on: \Product.$store.$id == \Store.$id)
            .filter(Store.self, \.$isActive == true)
            .all()
        
        var filteredProducts = products
        
        // Apply price filters in memory
        if let minPrice = try? req.query.get(Double.self, at: "minPrice"),
           let currency = try? req.query.get(String.self, at: "currency") {
            filteredProducts = filteredProducts.filter { product in
                guard let price = product.pricing[currency] else { return false }
                return price >= minPrice
            }
        }
        
        if let maxPrice = try? req.query.get(Double.self, at: "maxPrice"),
           let currency = try? req.query.get(String.self, at: "currency") {
            filteredProducts = filteredProducts.filter { product in
                guard let price = product.pricing[currency] else { return false }
                return price <= maxPrice
            }
        }
        
        return filteredProducts.map { ProductListResponseDTO(from: $0) }
    }
    
    // Get products for a specific store
    func getStoreProducts(req: Request) async throws -> [ProductListResponseDTO] {
        guard let storeId = req.parameters.get("storeId") else {
            throw Abort(.badRequest)
        }
        
        // Verify store exists and is active
        guard let store = try await Store.find(storeId, on: req.db),
              store.isActive else {
            throw Abort(.notFound, reason: "Store not found or inactive")
        }
        
        let products = try await Product.query(on: req.db)
            .filter(\.$store.$id == storeId)
            .filter(\.$isActive == true)
            .all()
        
        return products.map { ProductListResponseDTO(from: $0) }
    }
    
    // Get a specific product
    func show(req: Request) async throws -> ProductResponseDTO {
        guard let product = try await Product.find(req.parameters.get("productId"), on: req.db) else {
            throw Abort(.notFound)
        }
        
        // Check if the product's store is active
        guard try await product.$store.get(on: req.db).isActive else {
            throw Abort(.notFound, reason: "Store is inactive")
        }
        
        return ProductResponseDTO(from: product)
    }
    
    // Create a new product (staff/admin only)
    func create(req: Request) async throws -> ProductResponseDTO {
        let dto = try req.content.decode(CreateProductDTO.self)
        
        // Verify store exists and is active
        guard let store = try await Store.find(dto.storeId, on: req.db),
              store.isActive else {
            throw Abort(.notFound, reason: "Store not found or inactive")
        }
        
        let product = Product(
            storeId: store.id!,
            name: dto.name,
            description: dto.description,
            pricing: dto.pricing,
            category: dto.category,
            fabricOptions: dto.fabricOptions,
            availableColors: dto.availableColors,
            customizationOptions: dto.customizationOptions,
            images: dto.images,
            stockStatus: dto.stockStatus,
            isActive: true
        )
        
        try await product.save(on: req.db)
        return ProductResponseDTO(from: product)
    }
    
    // Update a product (staff/admin only)
    func update(req: Request) async throws -> ProductResponseDTO {
        guard let product = try await Product.find(req.parameters.get("productId"), on: req.db) else {
            throw Abort(.notFound)
        }
        
        let dto = try req.content.decode(CreateProductDTO.self)
        
        // Verify store exists and is active
        guard let store = try await Store.find(dto.storeId, on: req.db),
              store.isActive else {
            throw Abort(.notFound, reason: "Store not found or inactive")
        }
        
        product.$store.id = store.id!
        product.name = dto.name
        product.description = dto.description
        product.pricing = dto.pricing
        product.category = dto.category
        product.fabricOptions = dto.fabricOptions
        product.availableColors = dto.availableColors
        product.customizationOptions = dto.customizationOptions
        product.images = dto.images
        product.stockStatus = dto.stockStatus
        
        try await product.save(on: req.db)
        return ProductResponseDTO(from: product)
    }
    
    // Delete a product (staff/admin only)
    func delete(req: Request) async throws -> HTTPStatus {
        guard let product = try await Product.find(req.parameters.get("productId"), on: req.db) else {
            throw Abort(.notFound)
        }
        
        product.isActive = false
        try await product.save(on: req.db)
        return .ok
    }
} 
