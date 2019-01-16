import Foundation

public enum Constraint {
    case upToNextMajor(from: Version)
    case exact(Version)
    case ref(String)
}

public struct ImportSpecification {
    let importName: String
    let dependencyName: String
    let constraint: Constraint
}

/// - Parameter line: Contract: Single line string trimmed of whitespace.
public func parse(_ line: String) -> ImportSpecification? {
    let pattern = "import\\s+(.*?)\\s*//\\s*(.*?)\\s*(==|~>)\\s*(.*)"
    let rx = try! NSRegularExpression(pattern: pattern)
    guard let match = rx.firstMatch(in: line, range: line.nsRange) else { return nil }
    guard match.numberOfRanges == 5 else { return nil }

    let importName = extractImport(line: line.substring(with: match.range(at: 1))!)
    let depSpec = line.substring(with: match.range(at: 2))!
    let constrainer = line.substring(with: match.range(at: 3))!
    let requirement = line.substring(with: match.range(at: 4))!

    let depName: String
    if depSpec.hasPrefix("@") {
        depName = depSpec.dropFirst() + "/" + importName
    } else {
        depName = depSpec
    }

    let constraint: Constraint
    if let v = Version(tolerant: requirement) {
        if constrainer == "~>" {
            constraint = .upToNextMajor(from: v)
        } else {
            constraint = .exact(v)
        }
    } else {
        constraint = .ref(requirement)
    }

    return ImportSpecification(importName: importName, dependencyName: depName, constraint: constraint)
}

private func extractImport(line: String) -> String {
    //TODO throw if syntax is weird

    let parts = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)

    if parts.count == 1 {
        return line
    }

    return parts[1].split(separator: ".").first.map(String.init) ?? line
}
