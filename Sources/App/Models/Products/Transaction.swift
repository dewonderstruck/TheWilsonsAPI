import Fluent
import Vapor

enum TransactionStatus: String, Codable {
    case pending, success, failed
}

enum PaymentGateway: String, Codable {
    case razorpay, paypal
}

final class Transaction: Model, Content, @unchecked Sendable {
    static let schema = "transactions"
    static let database: DatabaseID = .transactions

    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "order_id")
    var order: Order
    
    @Field(key: "amount")
    var amount: Double
    
    @Enum(key: "status")
    var status: TransactionStatus
    
    @Enum(key: "payment_gateway")
    var paymentGateway: PaymentGateway
    
    init() { }
    
    init(id: UUID? = nil, orderID: UUID, amount: Double, status: TransactionStatus, paymentGateway: PaymentGateway) {
        self.id = id
        self.$order.id = orderID
        self.amount = amount
        self.status = status
        self.paymentGateway = paymentGateway
    }

    func toDTO() -> TransactionDTO {
        return TransactionDTO(id: self.id, orderID: self.$order.id, amount: self.amount, status: self.status, paymentGateway: self.paymentGateway)
    }
}
