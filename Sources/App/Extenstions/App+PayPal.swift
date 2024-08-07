import Vapor
import PayPalKit

extension Application {
    public struct PayPal {
        private final class Storage: Sendable {
            let clientId: String
            let clientSecret: String
            
            init(clientId: String, clientSecret: String) {
                self.clientId = clientId
                self.clientSecret = clientSecret
            }
        }
        
        private struct Key: StorageKey {
            typealias Value = Storage
        }
        
        private var storage: Storage {
            if self.application.storage[Key.self] == nil {
                self.initialize()
            }
            return self.application.storage[Key.self]!
        }
        
        public func initialize() {
            guard let clientId = Environment.get("PAYPAL_CLIENT_ID"),
                  let clientSecret = Environment.get("PAYPAL_CLIENT_SECRET") else {
                fatalError("No PayPal API client ID or secret provided")
            }
            self.application.storage[Key.self] = .init(clientId: clientId, clientSecret: clientSecret)
        }
        
        fileprivate let application: Application
        
        public var client: PayPalClient {
            .init(httpClient: self.application.http.client.shared, authType: .clientSecret(clientId: self.storage.clientId, secret: self.storage.clientSecret), environment: .sandbox)
        }
    }
    public var paypal: PayPal { .init(application: self) }
}
