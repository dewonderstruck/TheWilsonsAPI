// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "TheWilsonsAPI",
    platforms: [
       .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.102.1"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.11.0"),
        .package(url: "https://github.com/vapor/fluent-mongo-driver.git", from: "1.3.1"),
        .package(url: "https://github.com/vapor/leaf.git", from: "4.3.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.69.0"),
        .package(url: "https://github.com/vapor/jwt.git", from: "5.0.0-rc.1"),
        .package(url: "https://github.com/vapor/jwt-kit.git", from: "5.0.0-rc.1"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.5.2"),
        .package(url: "https://github.com/vamsii777/FirebaseAdmin.git", branch: "update/jwt-kit-to-5.0.0-rc.1"),
        .package(url: "https://github.com/hsharghi/swift-resend.git", from: "1.0.0"),
        .package(url: "https://github.com/vapor/queues-redis-driver.git", from: "1.0.0"),
        .package(url: "https://github.com/vamsii777/razorpay-kit.git", from: "0.0.9"),
        .package(url: "https://github.com/soto-project/soto.git", from: "7.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Resend", package: "swift-resend"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentMongoDriver", package: "fluent-mongo-driver"),
                .product(name: "Leaf", package: "leaf"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "JWT", package: "jwt"),
                .product(name: "JWTKit", package: "jwt-kit"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "FirebaseApp", package: "FirebaseAdmin"),
                .product(name: "FirebaseAuth", package: "FirebaseAdmin"),
                .product(name: "QueuesRedisDriver", package: "queues-redis-driver"),
                .product(name: "RazorpayKit", package: "razorpay-kit"),
                .product(name: "SotoS3", package: "soto")
            ],
            resources: [
                .copy("serviceAccount.json")
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "AppTests",
            dependencies: [
                .target(name: "App"),
                .product(name: "XCTVapor", package: "vapor"),
            ],
            swiftSettings: swiftSettings
        )
    ]
)

var swiftSettings: [SwiftSetting] { [
    .enableUpcomingFeature("DisableOutwardActorInference"),
    .enableExperimentalFeature("StrictConcurrency"),
] }
