import Vapor

struct CategoryDTO: Content {
    var id: UUID?
    var name: String

    func convertToPublic() -> CategoryDTO {
        return self
    }

    @Sendable
    func toModel() -> Category {
        let model = Category()
        model.name = self.name
        return model
    }
}