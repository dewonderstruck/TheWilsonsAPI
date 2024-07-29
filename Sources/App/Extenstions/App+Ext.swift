import Vapor

extension Application {
    struct Config {
        var publicURL: String
    }
    
    private struct ConfigKey: StorageKey {
        typealias Value = Config
    }
    
    var config: Config {
        get {
            if let existing = storage[ConfigKey.self] {
                return existing
            } else {
                let new = Config(publicURL: Environment.get("PUBLIC_URL") ?? "http://localhost:8080")
                storage[ConfigKey.self] = new
                return new
            }
        }
        set {
            storage[ConfigKey.self] = newValue
        }
    }
}