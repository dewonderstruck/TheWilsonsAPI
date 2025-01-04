import Foundation

public enum IDPrefix: String {
    case customer = "cust"
    case staff = "staff"
    case admin = "adm"
    
    public var separator: String { "_" }
    
    public func generate() -> String {
        let uuid = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(16)
        return "\(self.rawValue)\(separator)\(uuid)"
    }
} 