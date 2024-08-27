import Fluent
import Vapor

struct PaymentLinkController: RouteCollection {
    
    func boot(routes: RoutesBuilder) throws {
        let v1 = routes.grouped("v1")
        let paymentLinks = v1.grouped("payment_links")
        paymentLinks.get(use: index)
        paymentLinks.post(use: create)
        paymentLinks.group(":paymentLinkID") { paymentLink in
            paymentLink.delete(use: delete)
            paymentLink.put(use: update) // Added update route for consistency
        }
    }
    
    func index(req: Request) async throws -> [PaymentLinkDTO] {
        let paymentLinks = try await PaymentLink.query(on: req.db).all()
        return paymentLinks.map { $0.toDTO() }
    }

    func create(req: Request) async throws -> PaymentLinkDTO {
        guard let user = req.auth.get(User.self) else {
            throw Abort(.unauthorized)
        }
        let input = try req.content.decode(PaymentLinkDTO.self)
        let paymentLink = PaymentLink(
            name: input.name,
            description: input.description,
            amount: input.amount,
            userCreated: user.id!,
            userUpdated: nil
        )
        try await paymentLink.save(on: req.db)
        return paymentLink.toDTO()
    }

    func delete(req: Request) async throws -> HTTPStatus {
        guard let paymentLinkID = req.parameters.get("paymentLinkID", as: String.self) else {
            throw Abort(.badRequest, reason: "Missing payment link ID")
        }

        guard let paymentLink = try await PaymentLink.find(paymentLinkID, on: req.db) else {
            throw Abort(.notFound)
        }

        try await paymentLink.delete(on: req.db)
        return .ok
    }

    func update(req: Request) async throws -> PaymentLinkDTO {
        guard let paymentLinkID = req.parameters.get("paymentLinkID", as: String.self) else {
            throw Abort(.badRequest, reason: "Missing payment link ID")
        }

        guard let existingPaymentLink = try await PaymentLink.find(paymentLinkID, on: req.db) else {
            throw Abort(.notFound)
        }

        let updatedPaymentLinkData = try req.content.decode(PaymentLinkDTO.self)

        existingPaymentLink.name = updatedPaymentLinkData.name
        existingPaymentLink.description = updatedPaymentLinkData.description
        existingPaymentLink.amount = updatedPaymentLinkData.amount

        try await existingPaymentLink.update(on: req.db)
        return existingPaymentLink.toDTO()
    }
}
