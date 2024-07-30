import Vapor

struct OrderItemDTO: Content {
    var productID: Product.IDValue
    var quantity: Int
    var price: Double
    var createdAt: Date?
    var updatedAt: Date?
    var userCreated: User.IDValue
    var userUpdated: User.IDValue

    func convertToPublic() -> OrderItemDTO {
        return self
    }

    @Sendable
    func toModel() -> OrderItem {
        let model = OrderItem()
        model.product.id = self.productID
        model.quantity = self.quantity
        model.price = self.price
        model.createdAt = self.createdAt
        model.updatedAt = self.updatedAt
        model.userCreated.id = self.userCreated
        model.userUpdated.id = self.userUpdated
        return model
    }
}
