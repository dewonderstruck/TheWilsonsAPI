import Vapor
import Fluent
import Auth

public struct CustomizationController: RouteCollection {
    public init() {}
    
    public func boot(routes: RoutesBuilder) throws {
        let customizations = routes.grouped("customizations")
        
        // Public routes
        customizations.get("product", ":productId", use: getProductCustomizations)
        customizations.post("validate", ":productId", use: validateCustomizations)
        
        // Protected routes
        let protected = customizations.grouped(AuthMiddleware())
        let staffProtected = protected.grouped(PermissionMiddleware([
            Permission.createProduct,
            Permission.updateProduct
        ]))
        
        staffProtected.post(use: create)
        staffProtected.put(":customizationId", use: update)
        staffProtected.delete(":customizationId", use: delete)
    }
    
    // Get all customization options for a product
    func getProductCustomizations(req: Request) async throws -> [CustomizationOption] {
        guard let productId = req.parameters.get("productId") else {
            throw Abort(.badRequest)
        }
        
        // Verify product exists and is active
        guard let product = try await Product.find(productId, on: req.db),
              product.isActive else {
            throw Abort(.notFound, reason: "Product not found or inactive")
        }
        
        return try await CustomizationOption.query(on: req.db)
            .filter(\.$product.$id == productId)
            .sort(\.$displayOrder, .ascending)
            .all()
    }
    
    // Create a new customization option
    func create(req: Request) async throws -> CustomizationOption {
        let option = try req.content.decode(CustomizationOption.self)
        
        // Verify product exists
        guard let product = try await Product.find(option.$product.id, on: req.db) else {
            throw Abort(.notFound, reason: "Product not found")
        }
        
        try await option.save(on: req.db)
        return option
    }
    
    // Update a customization option
    func update(req: Request) async throws -> CustomizationOption {
        guard let option = try await CustomizationOption.find(req.parameters.get("customizationId"), on: req.db) else {
            throw Abort(.notFound)
        }
        
        let updated = try req.content.decode(CustomizationOption.self)
        
        option.name = updated.name
        option.type = updated.type
        option.description = updated.description
        option.options = updated.options
        option.displayOrder = updated.displayOrder
        option.isRequired = updated.isRequired
        option.expertSuggestions = updated.expertSuggestions
        option.metadata = updated.metadata
        
        try await option.save(on: req.db)
        return option
    }
    
    // Delete a customization option
    func delete(req: Request) async throws -> HTTPStatus {
        guard let option = try await CustomizationOption.find(req.parameters.get("customizationId"), on: req.db) else {
            throw Abort(.notFound)
        }
        
        try await option.delete(on: req.db)
        return .ok
    }
    
    // Validate customization values
    func validateCustomizations(req: Request) async throws -> HTTPStatus {
        guard let productId = req.parameters.get("productId") else {
            throw Abort(.badRequest)
        }
        
        let customizations = try req.content.decode([String: String].self)
        
        // Get all required customization options for the product
        let options = try await CustomizationOption.query(on: req.db)
            .filter(\.$product.$id == productId)
            .filter(\.$isRequired == true)
            .all()
        
        // Check if all required options are provided
        for option in options {
            guard let optionId = option.id else {
                continue // Skip if option has no ID
            }
            
            // Check if the required option is provided
            if let value = customizations[optionId] {
                // Validate the value based on option type
                switch option.type {
                case "slider":
                    let metadata = option.metadata ?? [:]
                    if let minStr = metadata["min"],
                       let maxStr = metadata["max"],
                       let min = Double(minStr),
                       let max = Double(maxStr),
                       let val = Double(value),
                       val >= min && val <= max {
                        // Value is valid
                    } else {
                        let minDisplay = option.metadata["min"] ?? "min"
                        let maxDisplay = option.metadata["max"] ?? "max"
                        throw Abort(.badRequest, reason: "Invalid value for \(option.name): must be between \(minDisplay) and \(maxDisplay)")
                    }
                    
                case "select", "color", "fabric":
                    if !option.options.keys.contains(value) {
                        throw Abort(.badRequest, reason: "Invalid option for \(option.name): \(value) is not a valid choice")
                    }
                    
                case "measurement":
                    guard let val = Double(value) else {
                        throw Abort(.badRequest, reason: "Invalid measurement value for \(option.name)")
                    }
                    
                    let metadata = option.metadata ?? [:]
                    if let minStr = metadata["min"],
                       let min = Double(minStr),
                       val < min {
                        throw Abort(.badRequest, reason: "\(option.name) must be at least \(min)")
                    }
                    if let maxStr = metadata["max"],
                       let max = Double(maxStr),
                       val > max {
                        throw Abort(.badRequest, reason: "\(option.name) must not exceed \(max)")
                    }
                    
                default:
                    // For any other type, just ensure the value is not empty
                    if value.isEmpty {
                        throw Abort(.badRequest, reason: "Empty value provided for \(option.name)")
                    }
                }
            } else {
                throw Abort(.badRequest, reason: "Missing required customization: \(option.name)")
            }
        }
        
        return .ok
    }
} 
