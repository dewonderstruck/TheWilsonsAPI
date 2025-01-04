import Vapor

struct CreateOrderDTO: Content {
    let productId: String
    let measurements: [String: Double]
    let customizations: [String: String]
    let selectedFabric: String
    let selectedColor: String
    let shippingAddress: [String: String]
    let specialInstructions: String?
}

struct OrderResponseDTO: Content {
    let id: String
    let userId: String
    let productId: String
    let status: String
    let totalAmount: Double
    let measurements: [String: Double]
    let customizations: [String: String]
    let selectedFabric: String
    let selectedColor: String
    let shippingAddress: [String: String]
    let specialInstructions: String?
    let createdAt: Date?
    let updatedAt: Date?
    
    init(from order: Order) throws {
        self.id = order.id!
        self.userId = order.$user.id
        self.productId = order.productId
        self.status = order.status
        self.totalAmount = order.totalAmount
        self.measurements = order.measurements
        self.customizations = order.customizations
        self.selectedFabric = order.selectedFabric
        self.selectedColor = order.selectedColor
        self.shippingAddress = order.shippingAddress
        self.specialInstructions = order.specialInstructions
        self.createdAt = order.createdAt
        self.updatedAt = order.updatedAt
    }
} 