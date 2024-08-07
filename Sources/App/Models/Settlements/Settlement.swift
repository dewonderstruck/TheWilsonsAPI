import Fluent
import Vapor

enum SettlementStatus: String, Codable {
    case pending, completed, failed
}

final class Settlement: Model, Content, @unchecked Sendable {
    static let schema = "settlements"
    static let database: DatabaseID = .settlements
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "transaction_id")
    var transaction: Transaction
    
    @Field(key: "amount")
    var amount: Double
    
    @Enum(key: "status")
    var status: SettlementStatus
    
    init() { }
    
    init(id: UUID? = nil, transactionID: UUID, amount: Double, status: SettlementStatus) {
        self.id = id
        self.$transaction.id = transactionID
        self.amount = amount
        self.status = status
    }

    func toDTO() -> SettlementDTO {
        return SettlementDTO(id: self.id, transactionID: self.$transaction.id, amount: self.amount, status: self.status)
    }
}
