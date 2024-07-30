import Vapor

struct TransactionDTO: Content {
    var id: UUID?
    var orderID: UUID
    var amount: Double
    var status: TransactionStatus
    var paymentGateway: PaymentGateway

    func convertToPublic() -> TransactionDTO {
        return self
    }

    @Sendable
    func toModel() -> Transaction {
        let model = Transaction()
        model.order.id = self.orderID
        model.amount = self.amount
        model.status = self.status
        model.paymentGateway = self.paymentGateway
        return model
    }
}
