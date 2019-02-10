// swift-tools-version:4.2
import PackageDescription

let package = Package(
    name: "swift-sh",
    products: [
        .executable(name: "swift-sh", targets: ["Executable"]),
        .library(name: "Library", targets: ["Library"]),
        .library(name: "Command", targets: ["Command"]),
    ],
    dependencies: [
        .package(url: "https://github.com/mxcl/Path.swift", from: "0.12.1"),
        .package(url: "https://github.com/mxcl/LegibleError", from: "1.0.0"),
        .package(url: "https://github.com/mxcl/Version", from: "1.0.0"),
    ],
    targets: [
        .target(name: "Executable", dependencies: ["Library", "Command", "LegibleError"], path: "Sources", sources: ["main.swift"]),
        .target(name: "Library", dependencies: ["Path", "Version"], path: "Sources/Library"),
        .target(name: "Command", dependencies: ["Library"], path: "Sources/Command"),
        .testTarget(name: "ShwiftyTests", dependencies: ["Executable"]),
    ]
)

package.swiftLanguageVersions = [.v4_2]
