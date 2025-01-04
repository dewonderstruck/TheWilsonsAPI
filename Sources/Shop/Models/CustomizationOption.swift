import Vapor
import Fluent

public final class CustomizationOption: Model, Content {
    public static let schema = "customization_options"
    
    @ID(custom: "id")
    public var id: String?
    
    @Field(key: "name")
    public var name: String
    
    @Field(key: "type")
    public var type: String  // "slider", "select", "color", "fabric", "measurement"
    
    @Field(key: "description")
    public var description: String
    
    @Field(key: "options")
    public var options: [String: CustomizationValue]
    
    @Field(key: "displayOrder")
    public var displayOrder: Int
    
    @Field(key: "isRequired")
    public var isRequired: Bool
    
    @Field(key: "expertSuggestions")
    public var expertSuggestions: [String: String]  // Contextual suggestions based on selection
    
    @Field(key: "metadata")
    public var metadata: [String: String]  // Additional configuration (e.g., slider min/max/step)
    
    @Parent(key: "productId")
    public var product: Product
    
    @Timestamp(key: "createdAt", on: .create)
    public var createdAt: Date?
    
    @Timestamp(key: "updatedAt", on: .update)
    public var updatedAt: Date?
    
    public init() { }
    
    public init(
        id: String? = nil,
        name: String,
        type: String,
        description: String,
        options: [String: CustomizationValue],
        displayOrder: Int = 0,
        isRequired: Bool = true,
        expertSuggestions: [String: String] = [:],
        metadata: [String: String] = [:],
        productId: Product.IDValue
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.description = description
        self.options = options
        self.displayOrder = displayOrder
        self.isRequired = isRequired
        self.expertSuggestions = expertSuggestions
        self.metadata = metadata
        self.$product.id = productId
    }
}

// Represents a customization value with additional metadata
public struct CustomizationValue: Codable {
    public var value: String
    public var displayName: String
    public var description: String?
    public var imageUrl: String?
    public var metadata: [String: String]?  // Additional data (e.g., fabric weight, color code)
    public var suggestions: [String: String]?  // Contextual suggestions
    
    public init(
        value: String,
        displayName: String,
        description: String? = nil,
        imageUrl: String? = nil,
        metadata: [String: String]? = nil,
        suggestions: [String: String]? = nil
    ) {
        self.value = value
        self.displayName = displayName
        self.description = description
        self.imageUrl = imageUrl
        self.metadata = metadata
        self.suggestions = suggestions
    }
} 