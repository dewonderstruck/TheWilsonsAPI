import Vapor

struct OrderItemDTO: Content {
    var productID: Product.IDValue
    var quantity: Int
    var price: Double

    func convertToPublic() -> OrderItemDTO {
        return self
    }

    @Sendable
    func toModel() -> OrderItem {
        let model = OrderItem()
        model.product.id = self.productID
        model.quantity = self.quantity
        model.price = self.price
        return model
    }
}
