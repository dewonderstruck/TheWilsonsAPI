import Fluent
import Vapor

struct SettlementControllerV1: RouteCollection {
    
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

    @Sendable
    func index(req: Request) async throws -> [SettlementDTO] {
        let settlements = try await Settlement.query(on: req.db).all()
        return settlements.map { $0.toDTO() }
    }

    @Sendable
    func create(req: Request) async throws -> SettlementDTO {
        let input = try req.content.decode(SettlementDTO.self)
        let settlement = Settlement(transactionID: input.transactionID, amount: input.amount, status: input.status)
        try await settlement.save(on: req.db)
        return settlement.toDTO()
    }

    @Sendable
    func show(req: Request) async throws -> SettlementDTO {
        guard let settlement = try await Settlement.find(req.parameters.get("settlementID"), on: req.db) else {
            throw Abort(.notFound)
        }
        return settlement.toDTO()
    }

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

    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        guard let settlement = try await Settlement.find(req.parameters.get("settlementID"), on: req.db) else {
            throw Abort(.notFound)
        }
        try await settlement.delete(on: req.db)
        return .noContent
    }
}
