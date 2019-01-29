// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "swift-sh",
    products: [
        .executable(name: "swift-sh", targets: ["Executable"]),
		.library(name: "Library", targets: ["Library"]),
        .library(name: "Command", targets: ["Command"]),
    ],
    dependencies: [
        .package(url: "https://github.com/mxcl/Path.swift", from: "0.8.0")
    ],
    targets: [
        .target(name: "Executable", dependencies: ["Library", "Command"], path: "Sources", sources: ["main.swift"]),
		.target(name: "Library", dependencies: ["Path"], path: "Sources/Library"),
        .target(name: "Command", dependencies: ["Library"], path: "Sources/Command"),
        .testTarget(name: "ShwiftyTests", dependencies: ["Executable"]),
    ]
)

package.platforms = [
   .macOS(.v10_10)
]
package.swiftLanguageVersions = [
    .v4_2, .v5
]
