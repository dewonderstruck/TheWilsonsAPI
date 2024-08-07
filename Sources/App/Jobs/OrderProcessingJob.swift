import Vapor
import Queues
import Fluent
import Resend

struct OrderProcessingJob: AsyncJob {
    typealias Payload = UUID
    
    func dequeue(_ context: QueueContext, _ payload: UUID) async throws {
        let logger = context.application.logger
        logger.info("Starting to process order: \(payload)")
        
        do {
            guard let order = try await Order.find(payload, on: context.application.db) else {
                throw Abort(.notFound, reason: "Order not found")
            }
            
            // Update order status to processing
            order.status = .processing
            try await order.save(on: context.application.db)
            logger.info("Order status updated to processing: \(payload)")
            
            // Generate payment link
            let paymentLink = try await generatePaymentLink(for: order, on: context)
            logger.info("Payment link generated for order: \(payload)")
            
            // Send payment link email
            try await sendPaymentLinkEmail(for: order, paymentLink: paymentLink, on: context)
            logger.info("Payment link email sent: \(payload)")
            
        } catch {
            logger.error("Error processing order \(payload): \(error)")
            throw error
        }
    }
    
    private func generatePaymentLink(for order: Order, on context: QueueContext) async throws -> String {
        // Implement the logic to generate a payment link using your preferred payment gateway
        // This is a placeholder implementation
        return "https://payment.gateway.com/pay/\(order.id!)"
    }
    
    private func sendPaymentLinkEmail(for order: Order, paymentLink: String, on context: QueueContext) async throws {
        let emailService = context.application.resend.client
        let user = try await order.$user.get(on: context.application.db)
        
        let email = ResendEmail(
            from: EmailAddress(email: "no-reply@thewilsonsbespoke.com", name: "The Wilson's Bespoke"),
            to: [EmailAddress(email: user.email)],
            subject: "Payment Link for Order #\(order.id?.uuidString ?? "")",
            html: "Please use the following link to complete your payment: \(paymentLink)"
        )
        
        try await emailService.emails.send(email: email)
    }
}
