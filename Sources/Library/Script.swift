import Foundation

public class Script {
    let name: String
    let deps: [ImportSpecification]
    let script: String

    var path: Path {
        return Path.selfCache/name
    }

    public init(name: String, contents: [String], dependencies: [ImportSpecification]) {
        self.name = name
        script = contents.joined(separator: "\n")
        deps = dependencies
    }
    
    var shouldWriteFiles: Bool {
        return (try? String(contentsOf: path/"main.swift")) != script
    }
    
    func write() throws {
        //TODO we only support Swift 4.2 basically
        //TODO dependency module names can be anything so we need to parse Package.swifts for all deps to get module lists

        var importNames: String {
            return deps.map { """
                "\($0.importName)"
                """
            }.joined(separator: ", ")
        }

        try path.mkpath()
        try """
            // swift-tools-version:4.2

            import PackageDescription

            let pkg = Package(name: "\(name)")
            pkg.products = [
                .executable(name: "\(name)", targets: ["\(name)"])
            ]
            pkg.dependencies = [
                \(deps.map{ $0.packageLine }.joined(separator: ",\n    "))
            ]
            pkg.targets = [
                .target(name: "\(name)", dependencies: [
                    \(importNames)
                ], path: ".", sources: ["main.swift"])
            ]

            """.write(to: path/"Package.swift")

        try script.write(to: path/"main.swift")
    }

    public func run() throws -> Never {
        if shouldWriteFiles {
            // don‘t write `main.swift` if would be identical
            // ∵ prevents swift-build recognizing a null-build
            // ie. prevents unecessary rebuild of our script
            try write()
        }

        guard FileManager.default.changeCurrentDirectoryPath(path.string) else {
            throw Error.directoryChangeFailed(path)
        }

        // first arg has to be same as
        let swiftPath = Library.swiftPath
        let cArgs = CStringArray([swiftPath, "run"])
        guard execv(swiftPath, cArgs.cArray) != -1 else {
            throw Error.swiftRun(cError: errno)
        }
        fatalError("Impossible if execv succeeded")
    }

    public enum Error: LocalizedError {
        case directoryChangeFailed(Path)
        case swiftRun(cError: Int32)

        public var errorDescription: String? {
            switch self {
            case .directoryChangeFailed(let path):
                return "could not chdir: \(path)"
            case .swiftRun(cError: let code):
                return "swift run failed: \(Library.strerror(code))"
            }
        }
    }
}

private  final class CStringArray {
    /// The null-terminated array of C string pointers.
    public let cArray: [UnsafeMutablePointer<Int8>?]

    /// Creates an instance from an array of strings.
    public init(_ array: [String]) {
        cArray = array.map({ $0.withCString({ strdup($0) }) }) + [nil]
    }

    deinit {
        for case let element? in cArray {
            free(element)
        }
    }
}

private extension ImportSpecification {
    var packageLine: String {
        var requirement: String {
            switch constraint {
            case .upToNextMajor(from: let v):
                return """
                    .upToNextMajor(from: "\(v)")
                    """
            case .exact(let v):
                return ".exactItem(Version(\(v.major),\(v.minor),\(v.patch)))"
            case .ref(let ref):
                return """
                    .revision("\(ref)")
                    """
            }
        }
        let urlstr: String
        if let url = URL(string: dependencyName), url.scheme != nil {
            urlstr = dependencyName
        } else {
            urlstr = "https://github.com/\(dependencyName).git"
        }
        return """
            .package(url: "\(urlstr)", \(requirement))
            """
    }
}

#if SWIFT_PACKAGE && DEBUG && !Xcode
private var swiftPath: String {
    var get: Path? {
        let yaml = Path.root.join(#file).parent.parent.join(".build/debug.yaml")
        guard let reader = try? StreamReader(path: yaml) else { return nil }
        for line in reader {
            guard let line = line.chuzzled() else { continue }
            if line.hasPrefix("executable:"), line.hasSuffix("swiftc\"") {
                let parts = line.split(separator: ":")
                guard parts.count == 2 else { continue }
                return Path.root.join(parts[1].trimmingCharacters(in: .init(charactersIn: " \n\""))).parent.join("swift")
            }
        }
        return nil
    }

    return get?.string ?? "/usr/bin/swift"
}
#elseif os(Linux)
private var swiftPath: String {
    let task = Process()
    task.launchPath = "/usr/bin/which"
    task.arguments = ["swift"]
    return (try? task.runSync())?.stdout.string?.chuzzled() ?? "/usr/bin/swift"
}
#else
//TODO find actual first swift in PATH like on Linux, but do a better implementation than the above
private let swiftPath = "/usr/bin/swift"
#endif


extension String {
    func chuzzled() -> String? {
        let s = trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? nil : s
    }
}

extension Path {
    static var selfCache: Path {
      #if os(macOS)
        return Path.home/"Library/Developer/swift-sh.cache"
      #else
        if let path = ProcessInfo.processInfo.environment["XDG_CACHE_HOME"] {
            return Path.root/path/"swift-sh"
        } else {
            return Path.home/".cache/swift-sh"
        }
      #endif
    }
}
