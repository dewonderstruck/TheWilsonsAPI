import Vapor

struct OrderDTO: Content {
    var id: UUID?
    var userID: User.IDValue
    var items: [OrderItemDTO]
    var total: Double
    var status: OrderStatus

    func convertToPublic() -> OrderDTO {
        return self
    }

    @Sendable
    func toModel() -> Order {
        let model = Order()
        model.user.id = self.userID
        model.total = self.total
        model.status = self.status
        return model
    }
}
