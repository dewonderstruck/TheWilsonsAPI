import Vapor
import Fluent

public final class Store: Model, Content {
    public static let schema = "stores"
    
    @ID(custom: "id")
    public var id: String?
    
    @Field(key: "name")
    public var name: String
    
    @Field(key: "region")
    public var region: String
    
    @Field(key: "currency")
    public var currency: String
    
    @Field(key: "address")
    public var address: [String: String]
    
    @Field(key: "contactInfo")
    public var contactInfo: [String: String]
    
    @Field(key: "timezone")
    public var timezone: String
    
    @Field(key: "isActive")
    public var isActive: Bool
    
    @Timestamp(key: "createdAt", on: .create)
    public var createdAt: Date?
    
    @Timestamp(key: "updatedAt", on: .update)
    public var updatedAt: Date?
    
    public init() { }
    
    public init(
        id: String? = nil,
        name: String,
        region: String,
        currency: String,
        address: [String: String],
        contactInfo: [String: String],
        timezone: String,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.region = region
        self.currency = currency
        self.address = address
        self.contactInfo = contactInfo
        self.timezone = timezone
        self.isActive = isActive
    }
} 