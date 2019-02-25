import Foundation
import Utility
import Version

/// - Parameter line: Contract: Single line string trimmed of whitespace.
func parse(_ line: String) -> ImportSpecification? {
    let pattern = "import\\s+(.*?)\\s*\\/\\/\\s*(@?[\\w\\/:\\.\\-]+)\\s*(?:(==|~>)\\s*([^\\s]+))?"
    let rx = try! NSRegularExpression(pattern: pattern)
    guard let match = rx.firstMatch(in: line) else { return nil }

    guard match.numberOfRanges == 5 else {
        return nil
    }

    let importName = extractImport(line: line[match.range(at: 1)])
    let depSpec = line[match.range(at: 2)]

    let depName: String
    if depSpec.hasPrefix("@") {
        depName = depSpec.dropFirst() + "/" + importName
    } else {
        depName = String(depSpec)
    }

    let constraint: Constraint
    if match.isMatch(at: 3), match.isMatch(at: 4) {
        let constrainer = line[match.range(at: 3)]
        let requirement = line[match.range(at: 4)]

        if let v = Version(tolerant: String(requirement)) {
            if constrainer == "~>" {
                constraint = .upToNextMajor(from: v)
            } else {
                constraint = .exact(v)
            }
        } else {
            constraint = .ref(String(requirement))
        }
    } else if match.isMatch(at: 3) || match.isMatch(at: 4) {
        //TODO show warning
        return nil
    } else {
        constraint = .latest
    }

    return ImportSpecification(importName: importName, dependencyName: depName, constraint: constraint)
}

private func extractImport<S>(line: S) -> String where S: StringProtocol {
    //TODO throw if syntax is weird

    let parts = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)

    if parts.count == 1 {
        return String(line)
    }

    return parts[1].split(separator: ".").first.map(String.init(_:)) ?? String(line)
}
