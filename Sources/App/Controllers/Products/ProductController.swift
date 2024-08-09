import Fluent
import Vapor

struct ProductController: RouteCollection {
    
    func boot(routes: RoutesBuilder) throws {
        let v1 = routes.grouped("v1")
        let products = v1.grouped("products")
        products.get(use: index)
        products.post(use: create)
        products.group(":productID") { product in
            product.get(use: show)
            product.put(use: update)
            product.delete(use: delete)
        }
    }

    @Sendable
    func index(req: Request) async throws -> [ProductDTO] {
        let products = try await Product.query(on: req.db).all().map { $0.toDTO() }
        return products
    }

    @Sendable
    func create(req: Request) async throws -> ProductDTO {
         guard let user = req.auth.get(User.self) else {
            throw Abort(.unauthorized)
        }
        let input = try req.content.decode(ProductDTO.self)
        let product = Product(name: input.name, description: input.description, price: input.price, userCreated: user.id!, userUpdated: user.id!)
        try await product.save(on: req.db)
        
        for categoryID in input.categoryIDs {
            guard let category = try await Category.find(categoryID, on: req.db) else {
                throw Abort(.badRequest, reason: "Category not found")
            }
            try await product.$categories.attach(category, on: req.db)
        }
        
        return ProductDTO(
            id: product.id,
            name: product.name,
            description: product.description,
            price: product.price,
            categoryIDs: input.categoryIDs,
            userCreated: try product.userCreated.requireID(),
            userUpdated: try product.userUpdated.requireID()
        )
    }

    @Sendable
    func show(req: Request) async throws -> ProductDTO {
        guard let product = try await Product.find(req.parameters.get("productID"), on: req.db) else {
            throw Abort(.notFound)
        }
        let categories = try await product.$categories.get(on: req.db)
        return ProductDTO(
            id: product.id,
            name: product.name,
            description: product.description,
            price: product.price,
            categoryIDs: categories.compactMap { $0.id },
            userCreated: try product.userCreated.requireID(),
            userUpdated: try product.userUpdated.requireID()
        )
    }

    @Sendable
    func update(req: Request) async throws -> ProductDTO {
        guard let user = req.auth.get(User.self) else {
           throw Abort(.unauthorized)
       }
        guard let product = try await Product.find(req.parameters.get("productID"), on: req.db) else {
            throw Abort(.notFound)
        }
        let input = try req.content.decode(ProductDTO.self)
        product.name = input.name
        product.description = input.description
        product.price = input.price
        product.userUpdated.id = input.userUpdated
        try await product.save(on: req.db)
        for categoryID in input.categoryIDs {
            guard let category = try await Category.find(categoryID, on: req.db) else {
                throw Abort(.badRequest, reason: "Category not found")
            }
            try await product.$categories.attach(category, on: req.db)
        }
        return ProductDTO(
            id: product.id,
            name: product.name,
            description: product.description,
            price: product.price,
            categoryIDs: input.categoryIDs,
            userCreated: try product.userCreated.requireID(),
            userUpdated: try product.userUpdated.requireID()
        )
    }

    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        guard let product = try await Product.find(req.parameters.get("productID"), on: req.db) else {
            throw Abort(.notFound)
        }
        try await product.delete(on: req.db)
        return .noContent
    }
}
