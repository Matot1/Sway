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
    targets: [
        .executableTarget(
            name: "Sway"
        )
    ]
)
