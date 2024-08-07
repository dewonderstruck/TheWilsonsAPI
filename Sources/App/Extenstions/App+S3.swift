import Vapor
import SotoS3

extension Application {
    public struct S3 {
        private final class Storage: Sendable {
            let client: AWSClient
            let s3: SotoS3.S3
            
            init(client: AWSClient, s3: SotoS3.S3) {
                self.client = client
                self.s3 = s3
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
            guard let accessKey = Environment.get("AWS_ACCESS_KEY_ID"),
                  let secretKey = Environment.get("AWS_SECRET_ACCESS_KEY"),
                  let region = Environment.get("AWS_REGION") else {
                fatalError("AWS credentials or region not set in environment variables")
            }
            
            let client = AWSClient(
                credentialProvider: .static(accessKeyId: accessKey, secretAccessKey: secretKey),
                httpClient: self.application.http.client.shared
            )
            
            let endpoint = Environment.get("AWS_S3_ENDPOINT")
            
            let s3 = SotoS3.S3(
                client: client,
                region: .init(rawValue: region),
                endpoint: endpoint
            )
            
            self.application.storage[Key.self] = .init(client: client, s3: s3)
        }
        
        fileprivate let application: Application
        
        public var client: SotoS3.S3 {
            storage.s3
        }
    }
    
    public var s3: S3 {
        .init(application: self)
    }
}

extension Request {
    public var s3: Application.S3 {
        .init(application: application)
    }
}
