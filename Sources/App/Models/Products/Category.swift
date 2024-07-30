import Vapor
import Fluent

final class Category: Model, Content, @unchecked Sendable {
    static let schema = "categories"
    static let database: DatabaseID = .products  
      
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "name")
    var name: String
    
    @Siblings(through: ProductCategory.self, from: \.$category, to: \.$product)
    var products: [Product]
    
    init() { }
    
    init(id: UUID? = nil, name: String) {
        self.id = id
        self.name = name
    }

     func toDTO() -> CategoryDTO {
        return CategoryDTO(id: self.id, name: self.name)
     }
}
