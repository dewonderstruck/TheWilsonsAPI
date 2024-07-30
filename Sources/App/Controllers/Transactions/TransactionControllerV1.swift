import Fluent
import Vapor

struct TransactionControllerV1: RouteCollection {
    
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

    @Sendable
    func index(req: Request) async throws -> [TransactionDTO] {
        let transactions = try await Transaction.query(on: req.db).all()
        return transactions.map { $0.toDTO() }
    }

    @Sendable
    func create(req: Request) async throws -> TransactionDTO {
        let input = try req.content.decode(TransactionDTO.self)
        let transaction = Transaction(orderID: input.orderID, amount: input.amount, status: input.status, paymentGateway: input.paymentGateway)
        try await transaction.save(on: req.db)
        return transaction.toDTO()
    }

    @Sendable
    func show(req: Request) async throws -> TransactionDTO {
        guard let transaction = try await Transaction.find(req.parameters.get("transactionID"), on: req.db) else {
            throw Abort(.notFound)
        }
        return transaction.toDTO()
    }

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

    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        guard let transaction = try await Transaction.find(req.parameters.get("transactionID"), on: req.db) else {
            throw Abort(.notFound)
        }
        try await transaction.delete(on: req.db)
        return .noContent
    }
}
