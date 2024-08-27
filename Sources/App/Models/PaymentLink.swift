import Vapor
import Fluent

struct Amount: Content {
    var value: Double
    var currency: String
}

final class PaymentLink: Model, Content, @unchecked Sendable {
    static let schema = "payment_links"
    static let database: DatabaseID = .products
    
    @ID(custom: "id", generatedBy: .user)
    var id: String?
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "description")
    var description: String
    
    @Field(key: "amount")
    var amount: Amount
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    @Parent(key: "user_created")
    var userCreated: User
    
    @OptionalParent(key: "user_updated") // Change to OptionalParent
    var userUpdated: User?
    
    init() { }
    
    init(id: String? = nil,
         name: String,
         description: String,
         amount: Amount,
         createdAt: Date? = nil,
         updatedAt: Date? = nil,
         userCreated: User.IDValue,
         userUpdated: User.IDValue? // Make userUpdated optional
    ) {
        self.id = id ?? PaymentLink.generateShortID()
        self.name = name
        self.description = description
        self.amount = amount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.$userCreated.id = userCreated
        if let userUpdated = userUpdated {
            self.$userUpdated.id = userUpdated
        }
    }
    
    func toDTO() -> PaymentLinkDTO {
        return PaymentLinkDTO(
            id: self.id,
            name: self.name,
            description: self.description,
            amount: self.amount,
            createdAt: self.createdAt,
            updatedAt: self.updatedAt,
            userCreated: self.userCreated.id,
            userUpdated: self.userUpdated?.id
        )
    }
    
    // Helper function to generate a short URL-friendly ID
    static func generateShortID(length: Int = 8) -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
        return String((0..<length).map { _ in characters.randomElement()! })
    }
}
