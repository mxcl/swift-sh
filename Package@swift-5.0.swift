// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "swift-sh",
    products: [
        .executable(name: "swift-sh", targets: ["Executable"]),
        .library(name: "Script", targets: ["Script"]),
        .library(name: "Utility", targets: ["Utility"]),
        .library(name: "Command", targets: ["Command"]),
    ],
    dependencies: [
        .package(url: "https://github.com/mxcl/Path.swift", from: "0.12.1"),
        .package(url: "https://github.com/mxcl/LegibleError", from: "1.0.0"),
        .package(url: "https://github.com/mxcl/Version", from: "1.0.0"),
    ],
    targets: [
        .target(name: "Executable", dependencies: ["Command", "LegibleError"], path: "Sources", sources: ["main.swift"]),
        .target(name: "Script", dependencies: ["Utility"]),
        .target(name: "Utility", dependencies: ["Path", "Version"]),
        .target(name: "Command", dependencies: ["Script"]),
        .testTarget(name: "All", dependencies: ["Executable"]),
    ]
)

package.platforms = [
   .macOS(.v10_10)
]

package.swiftLanguageVersions = [
    .v4_2, .v5
]
