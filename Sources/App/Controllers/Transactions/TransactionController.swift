import Fluent
import Vapor

/// A controller that handles CRUD operations for transactions.
struct TransactionController: RouteCollection {
    
    /// Registers the routes for the `TransactionController`.
    ///
    /// - Parameter routes: The `RoutesBuilder` to register routes on.
    /// - Throws: An error if the routes cannot be registered.
    func boot(routes: RoutesBuilder) throws {
        let v1 = routes.grouped("v1")
        let transactions = v1.grouped("transactions")
        transactions.get(use: index)
        transactions.post(use: create)
        transactions.group(":transactionID") { transaction in
            transaction.get(use: show)
            transaction.put(use: update)
            transaction.delete(use: delete)
        }
    }

    /// Retrieves all transactions.
    ///
    /// - Parameter req: The `Request` object.
    /// - Returns: An array of `TransactionDTO` objects.
    /// - Throws: An error if the transactions cannot be retrieved.
    @Sendable
    func index(req: Request) async throws -> [TransactionDTO] {
        let transactions = try await Transaction.query(on: req.db).all()
        return transactions.map { $0.toDTO() }
    }

    /// Creates a new transaction.
    ///
    /// - Parameter req: The `Request` object.
    /// - Returns: The created `TransactionDTO` object.
    /// - Throws: An error if the transaction cannot be created.
    @Sendable
    func create(req: Request) async throws -> TransactionDTO {
        let input = try req.content.decode(TransactionDTO.self)
        let transaction = Transaction(orderID: input.orderID, amount: input.amount, status: input.status, paymentGateway: input.paymentGateway)
        try await transaction.save(on: req.db)
        return transaction.toDTO()
    }

    /// Retrieves a specific transaction by its ID.
    ///
    /// - Parameter req: The `Request` object.
    /// - Returns: The `TransactionDTO` object.
    /// - Throws: An error if the transaction cannot be found.
    @Sendable
    func show(req: Request) async throws -> TransactionDTO {
        guard let transaction = try await Transaction.find(req.parameters.get("transactionID"), on: req.db) else {
            throw Abort(.notFound)
        }
        return transaction.toDTO()
    }

    /// Updates a specific transaction by its ID.
    ///
    /// - Parameter req: The `Request` object.
    /// - Returns: The updated `TransactionDTO` object.
    /// - Throws: An error if the transaction cannot be found or updated.
    @Sendable
    func update(req: Request) async throws -> TransactionDTO {
        guard let transaction = try await Transaction.find(req.parameters.get("transactionID"), on: req.db) else {
            throw Abort(.notFound)
        }
        let input = try req.content.decode(TransactionDTO.self)
        transaction.amount = input.amount
        transaction.status = input.status
        transaction.paymentGateway = input.paymentGateway
        try await transaction.save(on: req.db)
        return transaction.toDTO()
    }

    /// Deletes a specific transaction by its ID.
    ///
    /// - Parameter req: The `Request` object.
    /// - Returns: An HTTP status indicating the result of the operation.
    /// - Throws: An error if the transaction cannot be found or deleted.
    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        guard let transaction = try await Transaction.find(req.parameters.get("transactionID"), on: req.db) else {
            throw Abort(.notFound)
        }
        try await transaction.delete(on: req.db)
        return .noContent
    }
}