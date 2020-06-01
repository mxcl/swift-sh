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
    public init?(line: String, from input: Script.Input) throws {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("import") || trimmed.hasPrefix("@testable") else { return nil }
        guard let this = try parse(line, from: input) else { return nil }
        self = this
    }

    public var packageLine: String {
        switch dependencyName {
        case .local:
            return """
            .package(path: "\(dependencyName.urlString)")
            """
        case .scp, .url, .github:
            return """
            .package(url: "\(dependencyName.urlString)", \(requirement))
            """
        }
    }

    private var requirement: String {
        switch constraint {
        case .upToNextMajor(from: let v):
            return """
            .upToNextMajor(from: \(v.swiftDescription))
            """
        case .exact(let v):
            return """
            .exact(\(v.swiftDescription))
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
        #if swift(>=5.2)
            return map { """
                .product(name: "\($0.importName)", package: "\($0.dependencyName.packageName ?? "")")
                """
                }.joined(separator: ", ")
        #else
            return map { """
                "\($0.importName)"
                """
                }.joined(separator: ", ")
        #endif
    }

    var packageLines: String {
        return map{ $0.packageLine }.joined(separator: ",\n    ")
    }
}

private extension Version {
    var swiftDescription: String {
        //TODO not via string
        return """
            "\(self)"
            """
    }
}
