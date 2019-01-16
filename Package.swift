// swift-tools-version:4.2

import PackageDescription

let package = Package(
    name: "swift-sh",
    products: [
        .executable(name: "swift-sh", targets: ["Executable"]),
		.library(name: "Library", targets: ["Library"]),
        .library(name: "Command", targets: ["Command"]),
    ],
    targets: [
        .target(name: "Executable", dependencies: ["Library", "Command"], path: "Sources", sources: ["main.swift"]),
		.target(name: "Library", path: "Sources/Library"),
        .target(name: "Command", dependencies: ["Library"], path: "Sources/Command"),
        .testTarget(name: "ShwiftyTests", dependencies: ["Executable"]),
    ]
)
