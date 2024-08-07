import Vapor
import Queues
import Fluent
import Resend
import RazorpayKit


struct TransactionVerificationJob: AsyncJob {
    typealias Payload = UUID // Transaction ID
    
    func dequeue(_ context: QueueContext, _ payload: UUID) async throws {
        let logger = context.application.logger
        logger.info("Starting to verify transaction: \(payload)")
        
        do {
            guard let transaction = try await Transaction.find(payload, on: context.application.db) else {
                throw Abort(.notFound, reason: "Transaction not found")
            }
            
            let paymentGateway: PaymentGatewayProtocol
            
            if transaction.paymentGateway == .paypal {
                paymentGateway = PayPalGateway(configure: context.application.paypal)
            } else {
                let paymentGateway = RazorpayGateway(configure: context.application.razorpay)
            }
            
            let verificationResult = try await paymentGateway.verifyPayment(transactionId: transaction.id!)
            
            if verificationResult.success {
                transaction.status = .success
                try await transaction.save(on: context.application.db)
                
                // Update order status
                let order = try await transaction.$order.get(on: context.application.db)
                order.status = .completed
                try await order.save(on: context.application.db)
                
                // Send order confirmation email
                try await sendOrderConfirmationEmail(for: order, on: context)
            } else {
                transaction.status = .failed
                try await transaction.save(on: context.application.db)
                
                // Update order status
                let order = try await transaction.$order.get(on: context.application.db)
                order.status = .cancelled
                try await order.save(on: context.application.db)
                
                // Send payment failure email
                try await sendPaymentFailureEmail(for: order, on: context)
            }
            
            logger.info("Transaction verification completed: \(payload)")
        } catch {
            logger.error("Error verifying transaction \(payload): \(error)")
            throw error
        }
    }
    
    private func sendOrderConfirmationEmail(for order: Order, on context: QueueContext) async throws {
        let emailService = context.application.resend.client
        let user = try await order.$user.get(on: context.application.db)
        
        let email = ResendEmail(
            from: EmailAddress(email: "no-reply@thewilsonsbespoke.com", name: "The Wilson's Bespoke"),
            to: [EmailAddress(email: user.email)],
            subject: "Order Confirmation - #\(order.id?.uuidString ?? "")",
            html: "Your order has been successfully processed and is now complete."
        )
        
        try await emailService.emails.send(email: email)
    }
    
    private func sendPaymentFailureEmail(for order: Order, on context: QueueContext) async throws {
        let emailService = context.application.resend.client
        let user = try await order.$user.get(on: context.application.db)
        
        let email = ResendEmail(
            from: EmailAddress(email: "no-reply@thewilsonsbespoke.com", name: "The Wilson's Bespoke"),
            to: [EmailAddress(email: user.email)],
            subject: "Payment Failed - Order #\(order.id?.uuidString ?? "")",
            html: "We're sorry, but the payment for your order has failed. Please try again or contact customer support."
        )
        
        try await emailService.emails.send(email: email)
    }
}

protocol PaymentGatewayProtocol {
    func verifyPayment(transactionId: String) async throws -> PaymentVerificationResult
}

struct PaymentVerificationResult {
    let success: Bool
    let message: String
}

// These would be implemented elsewhere
struct PayPalGateway: PaymentGatewayProtocol {
    func verifyPayment(transactionId: String) async throws -> PaymentVerificationResult {
        
    }
}

struct RazorpayGateway: PaymentGatewayProtocol {
    
    let client: RazorpayClient
    
    init(configure: Application.Razorpay) {
        self.client = configure.client
    }

    func verifyPayment(transactionId: String) async throws -> PaymentVerificationResult {
        // Implement the verification logic here using the Razorpay client
        // This is a placeholder implementation
        do {
            // Assuming you have a method to fetch payment details using transactionId
            let paymentDetails = try await client.payment.fetch(paymentID: transactionId)
            let id = paymentDetails["id"]
            
            // Check the payment status
            if id == "paid" {
                return PaymentVerificationResult(success: true, message: "Payment verified successfully")
            } else {
                return PaymentVerificationResult(success: false, message: "Payment verification failed")
            }
        } catch {
            return PaymentVerificationResult(success: false, message: "Error verifying payment: \(error.localizedDescription)")
        }
    }
}
