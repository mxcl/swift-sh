import Foundation
import Version

extension ImportSpecification.Constraint: Codable {
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

    public static func ==(lhs: ImportSpecification.Constraint, rhs: ImportSpecification.Constraint) -> Bool {
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
