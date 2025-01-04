import Vapor
import Fluent

public final class Collection: Model, Content {
    public static let schema = "collections"
    
    @ID(custom: "id")
    public var id: String?
    
    @Field(key: "title")
    public var title: String
    
    @Field(key: "slug")
    public var slug: String
    
    @Field(key: "description")
    public var description: String
    
    @Field(key: "imageUrl")
    public var imageUrl: String?
    
    @Field(key: "isAutomated")
    public var isAutomated: Bool
    
    @Field(key: "conditions")
    public var conditions: [CollectionCondition]?
    
    @Field(key: "sortOrder")
    public var sortOrder: String  // e.g., "manual", "best-selling", "price-asc", "price-desc"
    
    @Field(key: "displayOrder")
    public var displayOrder: Int
    
    @Field(key: "isActive")
    public var isActive: Bool
    
    @Field(key: "metadata")
    public var metadata: [String: String]
    
    @Siblings(through: ProductCollection.self, from: \.$collection, to: \.$product)
    public var products: [Product]
    
    @Timestamp(key: "createdAt", on: .create)
    public var createdAt: Date?
    
    @Timestamp(key: "updatedAt", on: .update)
    public var updatedAt: Date?
    
    public init() { }
    
    public init(
        id: String? = nil,
        title: String,
        slug: String,
        description: String,
        imageUrl: String? = nil,
        isAutomated: Bool = false,
        conditions: [CollectionCondition]? = nil,
        sortOrder: String = "manual",
        displayOrder: Int = 0,
        isActive: Bool = true,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.slug = slug
        self.description = description
        self.imageUrl = imageUrl
        self.isAutomated = isAutomated
        self.conditions = conditions
        self.sortOrder = sortOrder
        self.displayOrder = displayOrder
        self.isActive = isActive
        self.metadata = metadata
    }
}

public struct CollectionCondition: Codable {
    public var field: String  // e.g., "title", "type", "price", "category"
    public var relation: String  // e.g., "equals", "not_equals", "greater_than", "contains"
    public var value: String
    
    public init(field: String, relation: String, value: String) {
        self.field = field
        self.relation = relation
        self.value = value
    }
} 