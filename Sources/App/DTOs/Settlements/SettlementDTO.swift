import Vapor

struct SettlementDTO: Content {
    var id: UUID?
    var transactionID: UUID
    var amount: Double
    var status: SettlementStatus

    func convertToPublic() -> SettlementDTO {
        return self
    }

    @Sendable
    func toModel() -> Settlement {
        let model = Settlement()
        model.transaction.id = self.transactionID
        model.amount = self.amount
        model.status = self.status
        return model
    }
}