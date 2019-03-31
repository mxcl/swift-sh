import struct Foundation.URL
import Version

public enum Constraint: Codable, Equatable {
    case upToNextMajor(from: Version)
    case exact(Version)
    case ref(String)
    case latest

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let str = try container.decode(String.self)
        func v() throws -> Version {
            guard let v = Version(String(str.dropFirst(2))) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid version")
            }
            return v
        }
        if str == "latest" {
            self = .latest
        } else if str.hasPrefix("~>") {
            self = .upToNextMajor(from: try v())
        } else if str.hasPrefix("==") {
            self = .exact(try v())
        } else if str.hasPrefix("@") {
            self = .ref(String(str.dropFirst()))
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid constraint")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .upToNextMajor(let from):
            try container.encode("~>\(from)")
        case .exact(let version):
            try container.encode("==\(version)")
        case .ref(let ref):
            try container.encode("@\(ref)")
        case .latest:
            try container.encode("latest")
        }
    }

    public static func ==(lhs: Constraint, rhs: Constraint) -> Bool {
        switch (lhs, rhs) {
        case (.upToNextMajor(let v1), .upToNextMajor(let v2)), (.exact(let v1), .exact(let v2)):
            return v1 == v2
        case let (.ref(ref1), .ref(ref2)):
            return ref1 == ref2
        case (.latest, .latest):
            return true
        case (.latest, _):
            return false
        case (.ref, _):
            return false
        case (.exact, _):
            return false
        case (.upToNextMajor, _):
            return false
        }
    }
}

public struct ImportSpecification: Codable, Equatable {
    let importName: String
    let dependencyName: String
    let constraint: Constraint
}

public extension ImportSpecification {
    init?(line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("import") || trimmed.hasPrefix("@testable") else { return nil }
        guard let result = parse(line) else { return nil }
        self = result
    }

    var packageLine: String {
        var requirement: String {
            switch constraint {
            case .upToNextMajor(from: let v):
                return """
                .upToNextMajor(from: Version(\(v.major),\(v.minor),\(v.patch)))
                """
            case .exact(let v):
                return """
                .exact(Version(\(v.major),\(v.minor),\(v.patch)))
                """
            case .ref(let ref):
                return """
                .revision("\(ref)")
                """
            case .latest:
                return """
                Version(0,0,0)...Version(1_000_000,0,0)
                """
            }
        }
        var urlstr: String = "https://github.com/\(dependencyName).git"
        if let url = URL(string: dependencyName) {
            switch url.scheme {
            case .some(let scheme):
                switch scheme {
                case "ssh":
                    let sshPrefix = "ssh://"
                    if dependencyName.hasPrefix(sshPrefix) {
                        urlstr = String(dependencyName.dropFirst(sshPrefix.count))
                    }
                default:
                    urlstr = dependencyName
                }
            case .none:
                let matchesCommonSSHURLFormat = dependencyName.contains("@") && dependencyName.contains(":")
                if matchesCommonSSHURLFormat {
                    urlstr = dependencyName
                } else {
                    urlstr = "https://github.com/\(dependencyName).git"
                }
            }
        }
        return """
        .package(url: "\(urlstr)", \(requirement))
        """
    }
}

public extension Array where Element == ImportSpecification {
    var mainTargetDependencies: String {
        return map { """
            "\($0.importName)"
            """
        }.joined(separator: ", ")
    }

    var packageLines: String {
        return map{ $0.packageLine }.joined(separator: ",\n    ")
    }
}
