import Fluent
import Vapor

final class OrderItem: Model, Content, @unchecked Sendable {
    static let schema = "order_items"
    static let database: DatabaseID = .orders
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "order_id")
    var order: Order
    
    @Parent(key: "product_id")
    var product: Product
    
    @Field(key: "quantity")
    var quantity: Int
    
    @Field(key: "price")
    var price: Double
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    @Parent(key: "user_created")
    var userCreated: User
    
    @Parent(key: "user_updated")
    var userUpdated: User
    
    init() { }
    
    init(id: UUID? = nil, orderID: UUID, productID: UUID, quantity: Int, price: Double, createdAt: Date? = nil, updatedAt: Date? = nil, userCreated: User.IDValue, userUpdated: User.IDValue) {
        self.id = id
        self.$order.id = orderID
        self.$product.id = productID
        self.quantity = quantity
        self.price = price
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.$userCreated.id = userCreated
        self.$userUpdated.id = userUpdated
    }
    
    func toDTO() -> OrderItemDTO {
        return OrderItemDTO(
            productID: self.$product.id,
            quantity: self.quantity,
            price: self.price,
            createdAt: self.createdAt,
            updatedAt: self.updatedAt,
            userCreated: self.$userCreated.id,
            userUpdated: self.$userUpdated.id
        )
    }
}
