import Vapor

struct ProductDTO: Content {
    var id: UUID?
    var name: String
    var description: String
    var price: Double
    var categoryIDs: [UUID]
    var createdAt: Date?
    var updatedAt: Date?

    func convertToPublic() -> ProductDTO {
        return self
    }

    @Sendable
    func toModel() -> Product {
        let model = Product()
        model.name = self.name
        model.description = self.description
        model.price = self.price
        model.createdAt = self.createdAt
        model.updatedAt = self.updatedAt
        return model
    }
}
