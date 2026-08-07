// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Sway",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Sway", targets: ["Sway"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "Sway",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ]
        )
    ]
)
