import Fluent
import Vapor

enum OrderStatus: String, Codable {
    case pending, processing, completed, cancelled
}

final class Order: Model, Content, @unchecked Sendable {
    static let schema = "orders"
    static let database: DatabaseID = .orders
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "user_id")
    var user: User
    
    @Children(for: \.$order)
    var items: [OrderItem]
    
    @Field(key: "total")
    var total: Double
    
    @Enum(key: "status")
    var status: OrderStatus
    
    init() { }
    
    init(id: UUID? = nil, userID: UUID, total: Double, status: OrderStatus) {
        self.id = id
        self.$user.id = userID
        self.total = total
        self.status = status
    }
    
    func toDTO() throws -> OrderDTO {
        return OrderDTO(
            id: try requireID(),
            userID: self.$user.id,
            items: self.$items.value?.map { $0.toDTO() } ?? [],
            total: self.total,
            status: self.status
        )
    }
}
