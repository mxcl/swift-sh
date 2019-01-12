import Foundation

public enum Constraint {
    case upToNextMajor(from: Version)
    case exact(Version)
    case ref(String)
}

public func parse(_ line: String) -> (String, Constraint)? {
    let pattern = "import\\s+(.*?)\\s*//\\s*(.*?)\\s+(==|~>)\\s+(.*)"
    let rx = try! NSRegularExpression(pattern: pattern)
    guard let match = rx.firstMatch(in: line, range: line.nsRange) else { return nil }
    guard match.numberOfRanges == 5 else { return nil }

    let importName = line.substring(with: match.range(at: 1))!
    let depSpec = line.substring(with: match.range(at: 2))!
    let constraint = line.substring(with: match.range(at: 3))!
    let requirement = line.substring(with: match.range(at: 4))!

    let depName: String
    if depSpec.hasPrefix("@") {
        depName = depSpec.dropFirst() + "/" + importName
    } else {
        depName = depSpec
    }

    if let v = Version(tolerant: requirement) {
        if constraint == "~>" {
            return (depName, .upToNextMajor(from: v))
        } else {
            return (depName, .exact(v))
        }
    } else {
        return (depName, .ref(requirement))
    }
}
