import Vapor
import Fluent

public final class Category: Model, Content {
    public static let schema = "categories"
    
    @ID(custom: "id")
    public var id: String?
    
    @Field(key: "name")
    public var name: String
    
    @Field(key: "slug")
    public var slug: String
    
    @Field(key: "description")
    public var description: String
    
    @OptionalParent(key: "parentId")
    public var parent: Category?
    
    @Children(for: \.$parent)
    public var children: [Category]
    
    @Field(key: "metadata")
    public var metadata: [String: String]
    
    @Field(key: "displayOrder")
    public var displayOrder: Int
    
    @Field(key: "isActive")
    public var isActive: Bool
    
    @Field(key: "type")
    public var type: String  // e.g., "gender", "style", "occasion"
    
    @Field(key: "imageUrl")
    public var imageUrl: String?
    
    @Siblings(through: ProductCategory.self, from: \.$category, to: \.$product)
    public var products: [Product]
    
    @Timestamp(key: "createdAt", on: .create)
    public var createdAt: Date?
    
    @Timestamp(key: "updatedAt", on: .update)
    public var updatedAt: Date?
    
    public init() { }
    
    public init(
        id: String? = nil,
        name: String,
        slug: String,
        description: String,
        parentId: String? = nil,
        metadata: [String: String] = [:],
        displayOrder: Int = 0,
        type: String,
        imageUrl: String? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.slug = slug
        self.description = description
        self.$parent.id = parentId
        self.metadata = metadata
        self.displayOrder = displayOrder
        self.type = type
        self.imageUrl = imageUrl
        self.isActive = isActive
    }
} 