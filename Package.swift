// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PersonalOSKit",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "ShellRunner", targets: ["ShellRunner"]),
        .library(name: "OllamaClient", targets: ["OllamaClient"]),
    ],
    targets: [
        .target(
            name: "ShellRunner",
            path: "Sources/ShellRunner"
        ),
        .target(
            name: "OllamaClient",
            path: "Sources/OllamaClient"
        ),
        .testTarget(
            name: "PersonalOSKitTests",
            dependencies: ["ShellRunner", "OllamaClient"],
            path: "Tests/PersonalOSKitTests"
        )
    ]
)
