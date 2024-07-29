import NIOSSL
import Fluent
import FluentMongoDriver
import Leaf
import JWT
import Vapor
import FirebaseApp
import Resend

extension Application {
    struct ResendKey: StorageKey {
        typealias Value = ResendClient
    }
    var resend: ResendClient {
        get {
            guard let client = storage[ResendKey.self] else {
                fatalError("Resend not configured. Use app.resend = ...")
            }
            return client
        }
        set {
            storage[ResendKey.self] = newValue
        }
    }
}
