// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "swift-sh",
    platforms: [
      .macOS(.v10_12)
    ],
    products: [
        .executable(name: "swift-sh", targets: ["swift-sh"]),
        .library(name: "Script", targets: ["Script"]),
        .library(name: "Utility", targets: ["Utility"]),
        .library(name: "Command", targets: ["Command"]),
    ],
    dependencies: [
        .package(url: "https://github.com/mxcl/Path.swift", from: "1.0.1"),
        .package(url: "https://github.com/mxcl/StreamReader", from: "1.0.0"),
        .package(url: "https://github.com/mxcl/LegibleError", from: "1.0.0"),
        .package(url: "https://github.com/mxcl/Version", from: "2.0.0"),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift", from: "1.4.0"),
    ],
    targets: [
        .target(
            name: "swift-sh",
            dependencies: ["Command", "LegibleError"],
            path: "Sources",
            exclude: ["Script", "Utility", "Command", "swift-sh-edit"],
            sources: ["main.swift"]),
        .target(
            name: "Script",
            dependencies: ["Utility", "StreamReader"]),
        .target(
            name: "Utility",
            dependencies: [
                .product(name: "Path", package: "Path.swift"),
                "Version",
                "CryptoSwift"
            ]),
        .target(
            name: "Command",
            dependencies: ["Script"]),
        .testTarget(
            name: "All",
            dependencies: ["swift-sh"]),
    ]
)

#if os(macOS)
package.products.append(.executable(name: "swift-sh-edit", targets: ["swift-sh-edit"]))
package.targets.append(.target(name: "swift-sh-edit", dependencies: ["XcodeProj", "Utility"]))
package.dependencies.append(.package(name: "XcodeProj", url: "https://github.com/tuist/xcodeproj", from: "7.0.0"))
#endif
