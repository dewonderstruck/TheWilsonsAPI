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

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Parent(key: "user_created")
    var userCreated: User

    @Parent(key: "user_updated")
    var userUpdated: User
    
    init() { }
    
    init(id: UUID? = nil, userID: UUID, total: Double, status: OrderStatus, createdAt: Date? = nil, updatedAt: Date? = nil, userCreated: User.IDValue, userUpdated: User.IDValue) {
        self.id = id
        self.$user.id = userID
        self.total = total
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.$userCreated.id = userCreated
        self.$userUpdated.id = userUpdated
    }
    
    func toDTO() throws -> OrderDTO {
        return OrderDTO(
            id: try requireID(),
            userID: self.$user.id,
            items: self.$items.value?.map { $0.toDTO() } ?? [],
            total: self.total,
            status: self.status,
            createdAt: self.createdAt,
            updatedAt: self.updatedAt,
            userCreated: self.$userCreated.id,
            userUpdated: self.$userUpdated.id
        )
    }
}
