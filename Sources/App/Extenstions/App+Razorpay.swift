import Vapor
import RazorpayKit

extension Application {
    public struct Razorpay {
        private final class Storage: Sendable {
            let key: String
            let secret: String
            
            init(key: String, secret: String) {
                self.key = key
                self.secret = secret
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
            guard let key = Environment.get("RAZORPAY_KEY"),
                  let secret = Environment.get("RAZORPAY_SECRET") else {
                fatalError("No Razorpay API key or secret provided")
            }
            
            self.application.storage[Key.self] = .init(key: key, secret: secret)
        }
        
        fileprivate let application: Application
        
        public var client: RazorpayClient {
            .init(httpClient: self.application.http.client.shared, key: self.storage.key, secret: self.storage.secret)
        }
    }
    
    public var razorpay: Razorpay { .init(application: self) }
}
