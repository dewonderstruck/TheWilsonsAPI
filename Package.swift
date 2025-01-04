// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "TheWilsons-API",
    platforms: [
       .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.111.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.12.0"),
        .package(url: "https://github.com/vapor/fluent-mongo-driver.git", from: "1.4.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
        .package(url: "https://github.com/vapor/jwt.git", from: "4.2.2"),
        .package(url: "https://github.com/vamsii777/swift-resend.git", branch: "main"),
        .package(url: "https://github.com/vapor/queues-redis-driver.git", from: "1.1.2"),
    ],
    targets: [
        .target(
            name: "Auth",
            dependencies: [
                .product(name: "JWT", package: "jwt"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentMongoDriver", package: "fluent-mongo-driver"),
                .product(name: "Resend", package: "swift-resend"),
                .product(name: "QueuesRedisDriver", package: "queues-redis-driver")
            ]
        ),  
        .target(
            name: "Shop",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .target(name: "Auth")
        ]),
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentMongoDriver", package: "fluent-mongo-driver"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .target(name: "Auth"),
                .target(name: "Shop")
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "AppTests",
            dependencies: [
                .target(name: "App"),
                .product(name: "VaporTesting", package: "vapor"),
            ],
            swiftSettings: swiftSettings
        )
    ],
    swiftLanguageModes: [.v5]
)

var swiftSettings: [SwiftSetting] { [
    .enableUpcomingFeature("DisableOutwardActorInference"),
    .enableExperimentalFeature("StrictConcurrency"),
] }
