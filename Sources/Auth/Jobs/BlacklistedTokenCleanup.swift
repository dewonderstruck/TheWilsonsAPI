import Vapor
import Queues
import Fluent

public struct BlacklistedTokenCleanup: AsyncScheduledJob {
    public init() {}
    
    public func run(context: QueueContext) async throws {
        // Delete all expired blacklisted tokens
        try await BlacklistedToken.query(on: context.application.db(.auth))
            .filter(\.$expiresAt < Date())
            .delete()
        
        context.logger.info("Cleaned up expired blacklisted tokens")
    }
} 