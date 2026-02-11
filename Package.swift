// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OllamaBot",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "OllamaBot", targets: ["OllamaBot"])
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.2.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0")
    ],
    targets: [
        .executableTarget(
            name: "OllamaBot",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm"),
                .product(name: "Yams", package: "Yams")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "OllamaBotTests",
            dependencies: ["OllamaBot"],
            path: "Tests"
        )
    ]
)
