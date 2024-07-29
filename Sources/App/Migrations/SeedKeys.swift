import Vapor
import Fluent

struct SeedKeys: AsyncMigration {
    func prepare(on database: Database) async throws {
        
        let publicKeyData = String(
        """
        -----BEGIN PUBLIC KEY-----
        MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEpn3DjIEzSoZrHjMWFXIud25D7isd
        Vs+w+MIyKA9V0xbSyx4cshfa1adPSNBvetNI3pQn3lCEnQFV43eZi14iaA==
        -----END PUBLIC KEY-----
        """)
        
        let privateKeyData = String(
        """
        -----BEGIN EC PRIVATE KEY-----
        MHcCAQEEINGqrIsI3VlNwNG/LITv/zEhM5JSx6EE+R5M8j1FVvqFoAoGCCqGSM49
        AwEHoUQDQgAEpn3DjIEzSoZrHjMWFXIud25D7isdVs+w+MIyKA9V0xbSyx4cshfa
        1adPSNBvetNI3pQn3lCEnQFV43eZi14iaA==
        -----END EC PRIVATE KEY-----
        """)
        
        let keys = [
            Key(kid: UUID(), keyType: .publicKey, keyData: publicKeyData),
            Key(kid: UUID(), keyType: .privateKey, keyData: privateKeyData)
        ]
        
        try await keys.create(on: database)
    }
    
    func revert(on database: Database) async throws {
        try await Key.query(on: database).delete()
    }
}
