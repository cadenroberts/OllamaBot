// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OllamaBotInstaller",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "OllamaBotInstaller", targets: ["OllamaBotInstaller"])
    ],
    targets: [
        .executableTarget(
            name: "OllamaBotInstaller",
            path: "Sources"
        )
    ]
)
