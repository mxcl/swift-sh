// swift-tools-version:4.2
import PackageDescription

let package = Package(
    name: "swift-sh",
    products: [
        .executable(name: "swift-sh", targets: ["swift-sh"]),
        .library(name: "Script", targets: ["Script"]),
        .library(name: "Utility", targets: ["Utility"]),
        .library(name: "Command", targets: ["Command"]),
    ],
    dependencies: [
        .package(url: "https://github.com/mxcl/Path.swift", from: "0.16.2"),
        .package(url: "https://github.com/mxcl/StreamReader", from: "1.0.0"),
        .package(url: "https://github.com/mxcl/LegibleError", from: "1.0.0"),
        .package(url: "https://github.com/mxcl/Version", from: "2.0.0"),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "0.15.0"),
    ],
    targets: [
        .target(name: "swift-sh", dependencies: ["Command", "LegibleError"], path: "Sources", sources: ["main.swift"]),
        .target(name: "Script", dependencies: ["Utility", "StreamReader"]),
        .target(name: "Utility", dependencies: ["Path", "Version", "CryptoSwift"]),
        .target(name: "Command", dependencies: ["Script"]),
        .testTarget(name: "All", dependencies: ["swift-sh"]),
    ],
    swiftLanguageVersions: [.v4_2, .version("5")]
)

#if os(macOS)
package.products.append(.executable(name: "swift-sh-edit", targets: ["swift-sh-edit"]))
package.targets.append(.target(name: "swift-sh-edit", dependencies: ["xcodeproj", "Utility"]))
package.dependencies.append(.package(url: "https://github.com/tuist/xcodeproj", from: "6.5.0"))
#endif
