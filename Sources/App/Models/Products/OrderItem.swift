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
    
    init() { }
    
    init(id: UUID? = nil, orderID: UUID, productID: UUID, quantity: Int, price: Double) {
        self.id = id
        self.$order.id = orderID
        self.$product.id = productID
        self.quantity = quantity
        self.price = price
    }
    
    func toDTO() -> OrderItemDTO {
        return OrderItemDTO(
            productID: self.$product.id,
            quantity: self.quantity,
            price: self.price
        )
    }
}
