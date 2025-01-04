import Vapor
import Auth
import Fluent

final class Order: Model, Content, @unchecked Sendable {
    static let schema = "orders"
    
    @ID(custom: "id")
    var id: String?
    
    @Parent(key: "userId")
    var user: User
    
    @Field(key: "productId")
    var productId: String
    
    @Field(key: "status")
    var status: String
    
    @Field(key: "totalAmount")
    var totalAmount: Double
    
    @Field(key: "measurements")
    var measurements: [String: Double]
    
    @Field(key: "customizations")
    var customizations: [String: String]
    
    @Field(key: "selectedFabric")
    var selectedFabric: String
    
    @Field(key: "selectedColor")
    var selectedColor: String
    
    @Field(key: "shippingAddress")
    var shippingAddress: [String: String]
    
    @Field(key: "specialInstructions")
    var specialInstructions: String?
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?
    
    init() { }
    
    init(
        id: String? = nil,
        userId: User.IDValue,
        productId: String,
        status: String,
        totalAmount: Double,
        measurements: [String: Double],
        customizations: [String: String],
        selectedFabric: String,
        selectedColor: String,
        shippingAddress: [String: String],
        specialInstructions: String? = nil
    ) {
        self.id = id
        self.$user.id = userId
        self.productId = productId
        self.status = status
        self.totalAmount = totalAmount
        self.measurements = measurements
        self.customizations = customizations
        self.selectedFabric = selectedFabric
        self.selectedColor = selectedColor
        self.shippingAddress = shippingAddress
        self.specialInstructions = specialInstructions
    }
} 
