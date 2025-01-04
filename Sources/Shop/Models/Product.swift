import Vapor
import Fluent

public final class Product: Model, Content {
    public static let schema = "products"
    
    @ID(custom: "id")
    public var id: String?
    
    @Parent(key: "storeId")
    public var store: Store
    
    @Field(key: "name")
    public var name: String
    
    @Field(key: "description")
    public var description: String
    
    @Field(key: "pricing")
    public var pricing: [String: Double]  // Currency code to price mapping
    
    @Field(key: "category")
    public var category: String
    
    @Field(key: "fabricOptions")
    public var fabricOptions: [String]
    
    @Field(key: "availableColors")
    public var availableColors: [String]
    
    @Field(key: "customizationOptions")
    public var customizationOptions: [String: [String]]
    
    @Field(key: "images")
    public var images: [String]
    
    @Field(key: "isActive")
    public var isActive: Bool
    
    @Field(key: "stockStatus")
    public var stockStatus: String
    
    @Timestamp(key: "createdAt", on: .create)
    public var createdAt: Date?
    
    @Timestamp(key: "updatedAt", on: .update)
    public var updatedAt: Date?
    
    public init() { }
    
    public init(
        id: String? = nil,
        storeId: Store.IDValue,
        name: String,
        description: String,
        pricing: [String: Double],
        category: String,
        fabricOptions: [String],
        availableColors: [String],
        customizationOptions: [String: [String]],
        images: [String],
        stockStatus: String = "in_stock",
        isActive: Bool = true
    ) {
        self.id = id
        self.$store.id = storeId
        self.name = name
        self.description = description
        self.pricing = pricing
        self.category = category
        self.fabricOptions = fabricOptions
        self.availableColors = availableColors
        self.customizationOptions = customizationOptions
        self.images = images
        self.stockStatus = stockStatus
        self.isActive = isActive
    }
} 