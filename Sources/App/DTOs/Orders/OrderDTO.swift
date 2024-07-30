import Vapor

struct OrderDTO: Content {
    var id: UUID?
    var userID: User.IDValue
    var items: [OrderItemDTO]
    var total: Double
    var status: OrderStatus
    var createdAt: Date?
    var updatedAt: Date?
    var userCreated: User.IDValue
    var userUpdated: User.IDValue

    func convertToPublic() -> OrderDTO {
        return self
    }

    @Sendable
    func toModel() -> Order {
        let model = Order()
        model.user.id = self.userID
        model.total = self.total
        model.status = self.status
        model.createdAt = self.createdAt
        model.updatedAt = self.updatedAt
        model.userCreated.id = self.userCreated
        model.userUpdated.id = self.userUpdated
        return model
    }
}
