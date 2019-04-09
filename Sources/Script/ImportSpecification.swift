import struct Foundation.URL
import Version
import Path

public struct ImportSpecification: Codable, Equatable {
    let importName: String
    let dependencyName: DependencyName
    let constraint: Constraint

    enum DependencyName: Equatable {
        case url(URL)
        case scp(String)
        case local(Path)
        case github(user: String, repo: String)
    }

    enum Constraint: Equatable {
        case upToNextMajor(from: Version)
        case exact(Version)
        case ref(String)
        case latest
    }
}

extension ImportSpecification {
    public init?(line: String) throws {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("import") || trimmed.hasPrefix("@testable") else { return nil }
        guard let this = try parse(line) else { return nil }
        self = this
    }

    public var packageLine: String {
        switch dependencyName {
        case .local:
            return """
            .package(path: "\(dependencyName.urlString)")
            """
        default:
            return """
            .package(url: "\(dependencyName.urlString)", \(requirement))
            """
        }
    }

    private var requirement: String {
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
