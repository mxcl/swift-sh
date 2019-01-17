import Foundation
import Library

public func eject(_ script: Path, force: Bool) throws {
    guard script.isFile else {
        throw CocoaError.error(.fileNoSuchFile)
    }

    let reader = try StreamReader(path: script).makeIterator()
    guard force || reader.next().isShebang else { throw EjectError.notScript }
    let deps = reader.compactMap(parse)
    let name = script.basename(dropExtension: true).capitalized
    let containingDirectory = script.parent

    try Path.mktemp { tmpdir in
        let sources = try tmpdir.join("Sources").mkdir()
        try script.copy(to: sources/"main.swift")

        try """
            // swift-tools-version:4.2
            import PackageDescription

            let pkg = Package(name: "\(name)")

            pkg.products = [
                .executable(name: "\(name)", targets: ["\(name)"])
            ]
            pkg.dependencies = [
                \(deps.packageLines)
            ]
            pkg.targets = [
                .target(name: "\(name)", dependencies: [\(deps.mainTargetDependencies)], path: "Sources")
            ]

            """.write(to: tmpdir/"Package.swift")

        let tmpscript = containingDirectory/"\(name).backup"
        do {
            try script.move(to: tmpscript)
            let result = try tmpdir.move(to: containingDirectory/name)
            print("created: \(result)")
        } catch {
            // try to recover
            try tmpscript.move(to: script)
            throw error
        }
        try tmpscript.delete()
    }
}

public extension CommandLine {
    //TODO find a good third party parser (like obv.)
    public static func parse<T>(eject args: T) throws -> (path: Path, force: Bool) where T: Collection, T.Element == String, T.Index == Int {

        func pathize(at: Int) -> Path {
            return Path(absolute: args[at]) ?? Path.cwd/args[at]
        }

        switch args.count {
        case 1:
            return (path: pathize(at: args.indices.first!), force: false)
        case 2:
            guard let flagIndex = args.firstIndex(of: "-f") ?? args.firstIndex(of: "--force") else {
                throw Error.invalidUsage
            }
            let firstIndex = args.indices.first!
            let pathIndex = flagIndex == firstIndex ? flagIndex.advanced(by: 1) : firstIndex
            let path = pathize(at: pathIndex)
            return (path: path, force: true)
        case 0, _:
            throw CommandLine.Error.invalidUsage
        }
    }
}

enum EjectError: LocalizedError {
    case notScript

    var errorDescription: String? {
        return "cannot eject; not Swift script (override with --force)"
    }
}

private extension Optional where Wrapped == String {
    var isShebang: Bool {
        switch self {
        case "#!/usr/bin/swift sh"?:
            return true
        case "#!/usr/bin/env swift sh"?:
            return true
        case "#!/usr/bin/swift-sh"?:
            return true
        case "#!/sbin/swift sh"?:  // unlikely but possible
            return true
        case "#!/bin/swift sh"?:   // unlikely but possible
            return true
        default:
            return false
        }
    }
}
