// swift-tools-version:4.2

import PackageDescription

let package = Package(
    name: "Shwifty",
    products: [
        .executable(name: "swift-sh", targets: ["exe"]),
		.library(name: "Shwifty", targets: ["Shwifty"])
    ],
    targets: [
        .target(name: "exe", dependencies: ["Shwifty"], path: ".", sources: ["main.swift"]),
		.target(name: "Shwifty", path: "Sources"),
        .testTarget(name: "ShwiftyTests", dependencies: ["Shwifty", "exe"]),
    ]
)
