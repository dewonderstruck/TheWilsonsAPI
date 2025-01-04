import Vapor

struct CreateProductDTO: Content {
    let storeId: String
    let name: String
    let description: String
    let pricing: [String: Double]  // Currency code to price mapping
    let category: String
    let fabricOptions: [String]
    let availableColors: [String]
    let customizationOptions: [String: [String]]
    let images: [String]
    let stockStatus: String
}

struct ProductResponseDTO: Content {
    let id: String
    let storeId: String
    let name: String
    let description: String
    let pricing: [String: Double]
    let category: String
    let fabricOptions: [String]
    let availableColors: [String]
    let customizationOptions: [String: [String]]
    let images: [String]
    let stockStatus: String
    let isActive: Bool
    let createdAt: Date?
    let updatedAt: Date?
    
    init(from product: Product) {
        self.id = product.id!
        self.storeId = product.$store.id
        self.name = product.name
        self.description = product.description
        self.pricing = product.pricing
        self.category = product.category
        self.fabricOptions = product.fabricOptions
        self.availableColors = product.availableColors
        self.customizationOptions = product.customizationOptions
        self.images = product.images
        self.stockStatus = product.stockStatus
        self.isActive = product.isActive
        self.createdAt = product.createdAt
        self.updatedAt = product.updatedAt
    }
}

struct ProductListResponseDTO: Content {
    let id: String
    let name: String
    let pricing: [String: Double]
    let category: String
    let images: [String]
    let stockStatus: String
    
    init(from product: Product) {
        self.id = product.id!
        self.name = product.name
        self.pricing = product.pricing
        self.category = product.category
        self.images = product.images
        self.stockStatus = product.stockStatus
    }
} 