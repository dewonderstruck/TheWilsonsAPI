import Vapor
import Fluent

// Define the StorageType enum
public enum StorageType: String, Codable, Sendable {
    case local
    case s3
}
