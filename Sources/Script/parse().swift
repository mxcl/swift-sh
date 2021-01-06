import Foundation
import Utility
import Version

enum E: Error {
    case invalidConstraint(String)
}

/// - Parameter line: Contract: Single line string trimmed of whitespace.
func parse(_ line: String, from input: Script.Input) throws -> ImportSpecification? {
    let importModNamePattern = "import\\s+(.*?)"
    let commentPattern = "\\/\\/"
    let localFilePattern = "(?:(?:~|[\\./]+)+?[\\w \\/\\.\\-]*)"
    let repoRefPattern = "(?:(?:[(@|\\w)]?[\\w\\/(@|:)\\.\\-]+))"
    let repoConstraintPattern = "(?:(==|~>)\\s*([^\\s]+))?"
    let pattern = "\(importModNamePattern)\\s*\(commentPattern)\\s*(\(localFilePattern)|\(repoRefPattern))\\s*\(repoConstraintPattern)"
    // or if you prefer, one big pattern:
    //      let pattern = "import\\s+(.*?)\\s*\\/\\/\\s*((?:(?:~|[\\./]+)+?[\\w \\/\\.\\-]*)|(?:(?:[(@|\\w)]?[\\w\\/(@|:)\\.\\-]+)))\\s*(?:(==|~>)\\s*([^\\s]+))?"
    let rx = try! NSRegularExpression(pattern: pattern)

    // match 0: whole string
    // match 1: module name
    // match 2: one of:
    //          user ref (e.g., @mxcl)
    //          local file ref (e.g., ./my/project or ../my/project or ~/foo, or /foo/bar)
    //          url ref (e.g., https://foo/bar.git or git@github.com:user/repo.git or ssh://git@github.com:user/repo.git)
    // match 3: range spec (e.g., ~> or ==) -- IFF NOT local file ref (and match 8 valid))
    // match 4: range value (e.g., 1.0.0-alpha.1 or b27a89 or 1) -- IFF NOT local file ref (and match 7 valid)
    
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
        dependencyName: try .init(rawValue: String(line[match.range(at: 2)]),
                                  importName: importName,
                                  from: input),
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
