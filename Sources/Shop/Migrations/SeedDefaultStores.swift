import Fluent

public struct SeedDefaultStores: AsyncMigration {
    public init() {}
    public func prepare(on database: Database) async throws {
        let stores: [[String: Any]] = [
            [
                "id": "store-india-delhi",
                "name": "The Wilsons Bespoke - Delhi",
                "region": "India",
                "currency": "INR",
                "address": [
                    "street": "123 Fashion Street",
                    "city": "New Delhi",
                    "state": "Delhi",
                    "country": "India",
                    "postalCode": "110001"
                ],
                "contactInfo": [
                    "email": "delhi@wilsonsbespoke.com",
                    "phone": "+91-11-12345678"
                ],
                "timezone": "Asia/Kolkata"
            ],
            [
                "id": "store-india-mumbai",
                "name": "The Wilsons Bespoke - Mumbai",
                "region": "India",
                "currency": "INR",
                "address": [
                    "street": "456 Fashion Avenue",
                    "city": "Mumbai",
                    "state": "Maharashtra",
                    "country": "India",
                    "postalCode": "400001"
                ],
                "contactInfo": [
                    "email": "mumbai@wilsonsbespoke.com",
                    "phone": "+91-22-12345678"
                ],
                "timezone": "Asia/Kolkata"
            ],
            [
                "id": "store-uae-dubai",
                "name": "The Wilsons Bespoke - Dubai",
                "region": "UAE",
                "currency": "AED",
                "address": [
                    "street": "789 Fashion Boulevard",
                    "city": "Dubai",
                    "state": "Dubai",
                    "country": "United Arab Emirates",
                    "postalCode": "12345"
                ],
                "contactInfo": [
                    "email": "dubai@wilsonsbespoke.com",
                    "phone": "+971-4-1234567"
                ],
                "timezone": "Asia/Dubai"
            ]
        ]
        
        for storeData in stores {
            let store = Store(
                id: storeData["id"] as? String,
                name: storeData["name"] as! String,
                region: storeData["region"] as! String,
                currency: storeData["currency"] as! String,
                address: storeData["address"] as! [String: String],
                contactInfo: storeData["contactInfo"] as! [String: String],
                timezone: storeData["timezone"] as! String,
                isActive: true
            )
            try await store.save(on: database)
        }
    }
    
    public func revert(on database: Database) async throws {
        try await Store.query(on: database).delete()
    }
} 