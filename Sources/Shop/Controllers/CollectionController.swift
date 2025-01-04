import Vapor
import Fluent
import Auth

public struct CollectionController: RouteCollection {
    public init() {}
    
    public func boot(routes: RoutesBuilder) throws {
        let collections = routes.grouped("collections")
        
        // Public routes
        collections.get(use: index)
        collections.get(":collectionId", use: show)
        collections.get("slug", ":slug", use: getBySlug)
        collections.get(":collectionId", "products", use: getCollectionProducts)
        
        // Protected routes
        let protected = collections.grouped(AuthMiddleware())
        let staffProtected = protected.grouped(PermissionMiddleware([
            Permission.manageCategories,
            Permission.manageCollections
        ]))
        
        staffProtected.post(use: create)
        staffProtected.put(":collectionId", use: update)
        staffProtected.delete(":collectionId", use: delete)
        staffProtected.post(":collectionId", "products", use: addProducts)
        staffProtected.delete(":collectionId", "products", use: removeProducts)
        staffProtected.put(":collectionId", "products", "reorder", use: reorderProducts)
    }
    
    // List all collections
    func index(req: Request) async throws -> [Collection] {
        var query = Collection.query(on: req.db)
            .filter(\.$isActive == true)
        
        // Apply sorting
        if let sortBy = try? req.query.get(String.self, at: "sort") {
            switch sortBy {
            case "title-asc":
                query = query.sort(\.$title, .ascending)
            case "title-desc":
                query = query.sort(\.$title, .descending)
            case "created-asc":
                query = query.sort(\.$createdAt, .ascending)
            case "created-desc":
                query = query.sort(\.$createdAt, .descending)
            default:
                query = query.sort(\.$displayOrder, .ascending)
            }
        } else {
            query = query.sort(\.$displayOrder, .ascending)
        }
        
        return try await query.all()
    }
    
    // Get a specific collection
    func show(req: Request) async throws -> Collection {
        guard let collection = try await Collection.find(req.parameters.get("collectionId"), on: req.db) else {
            throw Abort(.notFound)
        }
        return collection
    }
    
    // Get collection by slug
    func getBySlug(req: Request) async throws -> Collection {
        guard let slug = req.parameters.get("slug"),
              let collection = try await Collection.query(on: req.db)
                .filter(\.$slug == slug)
                .filter(\.$isActive == true)
                .first() else {
            throw Abort(.notFound)
        }
        return collection
    }
    
    // Get products in a collection
    func getCollectionProducts(req: Request) async throws -> [ProductListResponseDTO] {
        guard let collectionId = req.parameters.get("collectionId"),
              let collection = try await Collection.find(collectionId, on: req.db) else {
            throw Abort(.notFound)
        }
        
        // Load products with proper sorting
        var query = collection.$products.query(on: req.db)
            .filter(\.$isActive == true)
            .join(ProductCollection.self, on: \Product.$id == \ProductCollection.$product.$id)
            .filter(ProductCollection.self, \.$collection.$id == collectionId)
        
        // Apply collection-specific sorting
        switch collection.sortOrder {
        case "price-asc":
            // For price sorting, we need to consider the store's currency
            if let currency = try? req.query.get(String.self, at: "currency") {
                // Use MongoDB's field path for sorting with FieldKey
                query = query.sort([FieldKey.string("pricing_\(currency)")], .ascending)
            }
        case "price-desc":
            if let currency = try? req.query.get(String.self, at: "currency") {
                query = query.sort([FieldKey.string("pricing_\(currency)")], .descending)
            }
        case "manual":
            query = query.sort(ProductCollection.self, \.$position, .ascending)
        default:
            query = query.sort(\.$name, .ascending)
        }
        
        let products = try await query.all()
        return products.map { ProductListResponseDTO(from: $0) }
    }
    
    // Create a new collection
    func create(req: Request) async throws -> Collection {
        let collection = try req.content.decode(Collection.self)
        try await collection.save(on: req.db)
        
        // If it's an automated collection, process conditions immediately
        if collection.isAutomated {
            try await processAutomatedCollection(collection, on: req.db)
        }
        
        return collection
    }
    
    // Update a collection
    func update(req: Request) async throws -> Collection {
        guard let collection = try await Collection.find(req.parameters.get("collectionId"), on: req.db) else {
            throw Abort(.notFound)
        }
        
        let updated = try req.content.decode(Collection.self)
        
        collection.title = updated.title
        collection.slug = updated.slug
        collection.description = updated.description
        collection.imageUrl = updated.imageUrl
        collection.isAutomated = updated.isAutomated
        collection.conditions = updated.conditions
        collection.sortOrder = updated.sortOrder
        collection.displayOrder = updated.displayOrder
        collection.isActive = updated.isActive
        collection.metadata = updated.metadata
        
        try await collection.save(on: req.db)
        
        // If it's an automated collection, reprocess conditions
        if collection.isAutomated {
            try await processAutomatedCollection(collection, on: req.db)
        }
        
        return collection
    }
    
    // Soft delete a collection
    func delete(req: Request) async throws -> HTTPStatus {
        guard let collection = try await Collection.find(req.parameters.get("collectionId"), on: req.db) else {
            throw Abort(.notFound)
        }
        
        collection.isActive = false
        try await collection.save(on: req.db)
        return .ok
    }
    
    // Add products to a collection
    func addProducts(req: Request) async throws -> HTTPStatus {
        guard let collection = try await Collection.find(req.parameters.get("collectionId"), on: req.db) else {
            throw Abort(.notFound)
        }
        
        // Don't allow manual product addition to automated collections
        guard !collection.isAutomated else {
            throw Abort(.badRequest, reason: "Cannot manually add products to automated collections")
        }
        
        let productIds = try req.content.decode([String].self)
        
        // Get current max position
        let maxPosition = try await ProductCollection.query(on: req.db)
            .filter(\.$collection.$id == collection.id!)
            .max(\.$position) ?? 0
        
        // Add products
        for (index, productId) in productIds.enumerated() {
            guard let product = try await Product.find(productId, on: req.db) else { continue }
            
            // Check if relationship already exists
            let exists = try await ProductCollection.query(on: req.db)
                .filter(\.$product.$id == product.id!)
                .filter(\.$collection.$id == collection.id!)
                .first() != nil
            
            if !exists {
                try await ProductCollection(
                    productId: product.id!,
                    collectionId: collection.id!,
                    position: maxPosition + index + 1
                ).save(on: req.db)
            }
        }
        
        return .ok
    }
    
    // Remove products from a collection
    func removeProducts(req: Request) async throws -> HTTPStatus {
        guard let collection = try await Collection.find(req.parameters.get("collectionId"), on: req.db) else {
            throw Abort(.notFound)
        }
        
        // Don't allow manual product removal from automated collections
        guard !collection.isAutomated else {
            throw Abort(.badRequest, reason: "Cannot manually remove products from automated collections")
        }
        
        let productIds = try req.content.decode([String].self)
        
        try await ProductCollection.query(on: req.db)
            .filter(\.$collection.$id == collection.id!)
            .filter(\.$product.$id ~~ productIds)
            .delete()
        
        return .ok
    }
    
    // Reorder products in a collection
    func reorderProducts(req: Request) async throws -> HTTPStatus {
        guard let collection = try await Collection.find(req.parameters.get("collectionId"), on: req.db) else {
            throw Abort(.notFound)
        }
        
        // Don't allow manual reordering of automated collections
        guard !collection.isAutomated else {
            throw Abort(.badRequest, reason: "Cannot manually reorder products in automated collections")
        }
        
        let positions = try req.content.decode([String: Int].self)
        
        for (productId, position) in positions {
            guard let pivot = try await ProductCollection.query(on: req.db)
                .filter(\.$collection.$id == collection.id!)
                .filter(\.$product.$id == productId)
                .first() else { continue }
            
            pivot.position = position
            try await pivot.save(on: req.db)
        }
        
        return .ok
    }
    
    // Process automated collection conditions
    private func processAutomatedCollection(_ collection: Collection, on db: Database) async throws {
        guard let conditions = collection.conditions else { return }
        
        // Start with all active products
        var query = Product.query(on: db)
            .filter(\.$isActive == true)
        
        // Apply each condition
        for condition in conditions {
            switch condition.field {
            case "title":
                switch condition.relation {
                case "equals":
                    query = query.filter(\.$name == condition.value)
                case "contains":
                    // Use MongoDB's $regex for pattern matching
                    query = query.filter("name", .custom("$regex"), ".*\(condition.value).*")
                default:
                    continue
                }
                
            case "price":
                if let price = Double(condition.value) {
                    switch condition.relation {
                    case "greater_than":
                        // Use MongoDB's dot notation for nested fields
                        query = query.filter("pricing.USD", .greaterThan, price)
                    case "less_than":
                        query = query.filter("pricing.USD", .lessThan, price)
                    default:
                        continue
                    }
                }
                
            case "category":
                query = query.join(ProductCategory.self, on: \Product.$id == \ProductCategory.$product.$id)
                    .join(Category.self, on: \ProductCategory.$category.$id == \Category.$id)
                    .filter(Category.self, \.$slug == condition.value)
                
            default:
                continue
            }
        }
        
        // Get matching products
        let products = try await query.all()
        
        // Remove existing products
        try await ProductCollection.query(on: db)
            .filter(\.$collection.$id == collection.id!)
            .delete()
        
        // Add new products
        for (index, product) in products.enumerated() {
            try await ProductCollection(
                productId: product.id!,
                collectionId: collection.id!,
                position: index + 1
            ).save(on: db)
        }
    }
} 
