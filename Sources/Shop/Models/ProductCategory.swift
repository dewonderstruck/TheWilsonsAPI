import Fluent
import Foundation

public final class ProductCategory: Model {
    public static let schema = "product_categories"
    
    @ID(key: .id)
    public var id: UUID?
    
    @Parent(key: "productId")
    public var product: Product
    
    @Parent(key: "categoryId")
    public var category: Category
    
    @Field(key: "displayOrder")
    public var displayOrder: Int
    
    @Timestamp(key: "createdAt", on: .create)
    public var createdAt: Date?
    
    public init() { }
    
    public init(
        id: UUID? = nil,
        productId: Product.IDValue,
        categoryId: Category.IDValue,
        displayOrder: Int = 0
    ) throws {
        self.id = id
        self.$product.id = productId
        self.$category.id = categoryId
        self.displayOrder = displayOrder
    }
} 