import Vapor 
import Fluent

final class Product: Model, Content, @unchecked Sendable {
    static let schema = "products"
    static let database: DatabaseID = .products 

    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "description")
    var description: String
    
    @Field(key: "price")
    var price: Double

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    @Siblings(through: ProductCategory.self, from: \.$product, to: \.$category)
    var categories: [Category]
    
    init() { }
    
    init(id: UUID? = nil, 
    name: String, 
    description: String, 
    price: Double,
    createdAt: Date? = nil,
    updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.price = price
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

     func toDTO() -> ProductDTO {
        return ProductDTO(
            id: self.id, 
            name: self.name, 
            description: self.description, 
            price: self.price, 
            categoryIDs: self.categories.map { $0.id! },
            createdAt: self.createdAt,
            updatedAt: self.updatedAt
            )
     }
}
