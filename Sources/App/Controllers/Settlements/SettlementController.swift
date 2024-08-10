import Fluent
import Vapor

/// A controller that handles CRUD operations for settlements.
struct SettlementController: RouteCollection {
    
    /// Registers the routes for the `SettlementController`.
    ///
    /// - Parameter routes: The `RoutesBuilder` to register routes on.
    /// - Throws: An error if the routes cannot be registered.
    func boot(routes: RoutesBuilder) throws {
        let v1 = routes.grouped("v1")
        let settlements = v1.grouped("settlements")
        settlements.get(use: index)
        settlements.post(use: create)
        settlements.group(":settlementID") { settlement in
            settlement.get(use: show)
            settlement.put(use: update)
            settlement.delete(use: delete)
        }
    }

    /// Retrieves all settlements.
    ///
    /// - Parameter req: The `Request` object.
    /// - Returns: An array of `SettlementDTO` objects.
    /// - Throws: An error if the settlements cannot be retrieved.
    @Sendable
    func index(req: Request) async throws -> [SettlementDTO] {
        let settlements = try await Settlement.query(on: req.db).all()
        return settlements.map { $0.toDTO() }
    }

    /// Creates a new settlement.
    ///
    /// - Parameter req: The `Request` object.
    /// - Returns: The created `SettlementDTO` object.
    /// - Throws: An error if the settlement cannot be created.
    @Sendable
    func create(req: Request) async throws -> SettlementDTO {
        let input = try req.content.decode(SettlementDTO.self)
        let settlement = Settlement(transactionID: input.transactionID, amount: input.amount, status: input.status)
        try await settlement.save(on: req.db)
        return settlement.toDTO()
    }

    /// Retrieves a specific settlement by its ID.
    ///
    /// - Parameter req: The `Request` object.
    /// - Returns: The `SettlementDTO` object.
    /// - Throws: An error if the settlement cannot be found.
    @Sendable
    func show(req: Request) async throws -> SettlementDTO {
        guard let settlement = try await Settlement.find(req.parameters.get("settlementID"), on: req.db) else {
            throw Abort(.notFound)
        }
        return settlement.toDTO()
    }

    /// Updates a specific settlement by its ID.
    ///
    /// - Parameter req: The `Request` object.
    /// - Returns: The updated `SettlementDTO` object.
    /// - Throws: An error if the settlement cannot be found or updated.
    @Sendable
    func update(req: Request) async throws -> SettlementDTO {
        guard let settlement = try await Settlement.find(req.parameters.get("settlementID"), on: req.db) else {
            throw Abort(.notFound)
        }
        let input = try req.content.decode(SettlementDTO.self)
        settlement.amount = input.amount
        settlement.status = input.status
        try await settlement.save(on: req.db)
        return settlement.toDTO()
    }

    /// Deletes a specific settlement by its ID.
    ///
    /// - Parameter req: The `Request` object.
    /// - Returns: An HTTP status indicating the result of the operation.
    /// - Throws: An error if the settlement cannot be found or deleted.
    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        guard let settlement = try await Settlement.find(req.parameters.get("settlementID"), on: req.db) else {
            throw Abort(.notFound)
        }
        try await settlement.delete(on: req.db)
        return .noContent
    }
}