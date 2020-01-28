import StreamReader
import Foundation
import Utility
import Script
import Path

public func eject(_ script: Path, force: Bool) throws {
    guard script.isFile else {
        throw CocoaError.error(.fileNoSuchFile)
    }

    let reader = try StreamReader(path: script).makeIterator()
    guard force || reader.next().isShebang else { throw EjectError.notScript }
    let input:Script.Input = .path(script)
    let deps = try reader.compactMap { try ImportSpecification(line: $0, from: input) }
    let name = script.basename(dropExtension: true).capitalized
    let containingDirectory = script.parent

    try Path.mktemp { tmpdir in
        let sources = try tmpdir.join("Sources").mkdir()
        try script.copy(to: sources/"main.swift")

        try """
            // swift-tools-version:4.2
            import PackageDescription

            let package = Package(name: "\(name)")

            package.products = [
                .executable(name: "\(name)", targets: ["\(name)"])
            ]
            package.dependencies = [
                \(deps.packageLines)
            ]
            package.targets = [
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
