import Vapor

struct PaymentLinkDTO: Content {
    var id: String?
    var name: String
    var description: String
    var amount: Amount
    var createdAt: Date?
    var updatedAt: Date?
    var userCreated: User.IDValue?
    var userUpdated: User.IDValue?

    func convertToPublic() -> PaymentLinkDTO {
        return self
    }
}
