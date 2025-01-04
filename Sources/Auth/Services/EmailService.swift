import Vapor
import Resend

public protocol EmailService {
    func sendVerificationEmail(to: String, name: String?, token: String) async throws
    func sendWelcomeEmail(to: String, name: String?) async throws
    func sendPasswordResetEmail(to: String, name: String?, token: String) async throws
}

// MARK: - Application Extensions
public extension Application {
    struct EmailServices {
        let app: Application
        
        public struct Provider {
            let run: (Application) -> EmailService
            
            public init(_ run: @escaping (Application) -> EmailService) {
                self.run = run
            }
            
            public static func resend() -> Self {
                .init { app in
                    ResendEmailService(application: app)
                }
            }
            
            public static func mock() -> Self {
                .init { _ in
                    MockEmailService()
                }
            }
        }
        
        public func use(_ provider: Provider) {
            app.storage[EmailServiceKey.self] = provider.run(app)
        }
        
        var service: EmailService {
            guard let service = app.storage[EmailServiceKey.self] else {
                fatalError("EmailService not configured. Use app.emails.use()")
            }
            return service
        }
    }
    
    var emails: EmailServices {
        .init(app: self)
    }
}

// MARK: - Request Extension
public extension Request {
    var emailService: EmailService {
        application.emails.service
    }
}

// MARK: - Storage Key
private struct EmailServiceKey: StorageKey {
    typealias Value = EmailService
}

// MARK: - Resend Email Service Implementation
private struct ResendEmailService: EmailService {
    private let client: ResendClient
    private let fromEmail: String
    private let fromName: String
    
    init(application: Application) {
        guard let apiKey = Environment.get("RESEND_API_KEY") else {
            fatalError("RESEND_API_KEY env key missing. Create one at https://resend.com")
        }
        
        self.client = ResendClient(httpClient: application.http.client.shared, apiKey: apiKey)
        self.fromEmail = Environment.get("EMAIL_FROM") ?? "no-reply@church.com"
        self.fromName = Environment.get("EMAIL_FROM_NAME") ?? "Church App"
    }
    
    func sendVerificationEmail(to email: String, name: String?, token: String) async throws {
        let verifyLink = Environment.get("APP_URL") ?? "http://localhost:3000"
        let verifyUrl = "\(verifyLink)/verify-email?token=\(token)"
        
        let greeting = name.map { "Hello \($0)" } ?? "Hello"
        let html = """
        <html>
        <body>
            <h1>\(greeting)</h1>
            <p>Please verify your email address by clicking the link below:</p>
            <p><a href="\(verifyUrl)">Verify Email Address</a></p>
            <p>If you did not create an account, no further action is required.</p>
            <p>Best regards,<br>Church App Team</p>
        </body>
        </html>
        """
        
        let email = ResendEmail(
            from: .init(email: fromEmail, name: fromName),
            to: [EmailAddress(stringLiteral: email)],
            subject: "Verify your email address",
            html: html,
            tags: [.init(name: "type", value: "verification")]
        )
        
        _ = try await client.emails.send(email: email)
    }
    
    func sendPasswordResetEmail(to email: String, name: String?, token: String) async throws {
        let resetLink = Environment.get("APP_URL") ?? "http://localhost:3000"
        let resetUrl = "\(resetLink)/reset-password?token=\(token)"
        
        let greeting = name.map { "Hello \($0)" } ?? "Hello"
        let html = """
        <html>
        <body>
            <h1>\(greeting)</h1>
            <p>You are receiving this email because we received a password reset request for your account.</p>
            <p><a href="\(resetUrl)">Reset Password</a></p>
            <p>If you did not request a password reset, no further action is required.</p>
            <p>Best regards,<br>Church App Team</p>
        </body>
        </html>
        """
        
        let email = ResendEmail(
            from: .init(email: fromEmail, name: fromName),
            to: [EmailAddress(stringLiteral: email)],
            subject: "Reset your password",
            html: html,
            tags: [.init(name: "type", value: "password_reset")]
        )
        
        _ = try await client.emails.send(email: email)
    }
    
    func sendWelcomeEmail(to email: String, name: String?) async throws {
        let greeting = name.map { "Hello \($0)" } ?? "Hello"
        let html = """
        <html>
        <body>
            <h1>\(greeting)</h1>
            <p>Welcome to Church App! We're excited to have you join our community.</p>
            <p>You can now:</p>
            <ul>
                <li>View upcoming events</li>
                <li>Subscribe to newsletters</li>
                <li>Watch livestreams</li>
                <li>And much more!</li>
            </ul>
            <p>Best regards,<br>Church App Team</p>
        </body>
        </html>
        """
        
        let email = ResendEmail(
            from: .init(email: fromEmail, name: fromName),
            to: [EmailAddress(stringLiteral: email)],
            subject: "Welcome to Church App",
            html: html,
            tags: [.init(name: "type", value: "welcome")]
        )
        
        _ = try await client.emails.send(email: email)
    }
}

// MARK: - Mock Email Service for Testing
private struct MockEmailService: EmailService {
    func sendVerificationEmail(to: String, name: String?, token: String) async throws {
        print("Mock: Sending verification email to \(to) with token \(token)")
    }
    
    func sendPasswordResetEmail(to: String, name: String?, token: String) async throws {
        print("Mock: Sending password reset email to \(to) with token \(token)")
    }
    
    func sendWelcomeEmail(to: String, name: String?) async throws {
        print("Mock: Sending welcome email to \(to)")
    }
} 
