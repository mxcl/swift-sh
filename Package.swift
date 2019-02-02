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
        .package(url: "https://github.com/mxcl/Path.swift", from: "0.10.0"),
        .package(url: "https://github.com/alexito4/ImportSpecification", from: "0.3.0")
    ],
    targets: [
        .target(name: "Executable", dependencies: ["Library", "Command"], path: "Sources", sources: ["main.swift"]),
        .target(name: "Library", dependencies: ["Path", "ImportSpecification"], path: "Sources/Library"),
        .target(name: "Command", dependencies: ["Library"], path: "Sources/Command"),
        .testTarget(name: "ShwiftyTests", dependencies: ["Executable"]),
    ]
)
