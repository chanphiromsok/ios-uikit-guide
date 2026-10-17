// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BankKit",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "Networking", targets: ["Networking"]),
        .library(name: "Banking", targets: ["Banking"]),
    ],
    targets: [
        .target(name: "Networking"),
        .target(name: "Banking", dependencies: ["Networking"]),   // features depend on Core, never the other way
        .testTarget(name: "NetworkingTests", dependencies: ["Networking"]),
        .testTarget(name: "BankingTests", dependencies: ["Banking"]),
    ]
)
