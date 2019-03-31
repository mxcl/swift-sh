import Foundation
import Utility
import Version

enum E: Error {
    case invalidConstraint(String)
}

/// - Parameter line: Contract: Single line string trimmed of whitespace.
func parse(_ line: String) throws -> ImportSpecification? {
    let pattern = "import\\s+(.*?)\\s*\\/\\/\\s*(@?[\\w\\/(@|:)\\.\\-]+)\\s*(?:(==|~>)\\s*([^\\s]+))?"
    let rx = try! NSRegularExpression(pattern: pattern)

    // doesn’t look like an import line, we have to silently ignore it, even though it could
    // be a typo or whatever which is not useful to our user, but at the end of the day
    // we’re a hack waiting for a real API in Swift itself that can then error properly
    // rather than ignore lines since otherwise we’d print errors for normal comments!
    guard let match = rx.firstMatch(in: line), match.numberOfRanges == 5 else {
        return nil
    }

    let importName = extractImport(line: line[match.range(at: 1)])

    let constraint: ImportSpecification.Constraint
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
        throw E.invalidConstraint(line)
    } else {
        constraint = .latest
    }

    return ImportSpecification(
        importName: importName,
        dependencyName: try .init(rawValue: String(line[match.range(at: 2)]), importName: importName),
        constraint: constraint)
}

private func extractImport<S>(line: S) -> String where S: StringProtocol {
    //TODO throw if syntax is weird

    let parts = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)

    if parts.count == 1 {
        return String(line)
    }

    return parts[1].split(separator: ".").first.map(String.init(_:)) ?? String(line)
}
