import Fluent
import Foundation

public final class ProductCollection: Model {
    public static let schema = "product_collections"
    
    @ID(key: .id)
    public var id: UUID?
    
    @Parent(key: "productId")
    public var product: Product
    
    @Parent(key: "collectionId")
    public var collection: Collection
    
    @Field(key: "position")
    public var position: Int
    
    @Field(key: "featured")
    public var featured: Bool
    
    @Timestamp(key: "createdAt", on: .create)
    public var createdAt: Date?
    
    public init() { }
    
    public init(
        id: UUID? = nil,
        productId: Product.IDValue,
        collectionId: Collection.IDValue,
        position: Int = 0,
        featured: Bool = false
    ) throws {
        self.id = id
        self.$product.id = productId
        self.$collection.id = collectionId
        self.position = position
        self.featured = featured
    }
} 