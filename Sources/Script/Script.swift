import Foundation
import Utility
import Path

public class Script {
    let name: String
    let deps: [ImportSpecification]
    let script: String
    let args: [String]

    var path: Path {
        return Path.selfCache/name
    }

    public init(name: String, contents: [String], dependencies: [ImportSpecification], arguments: [String]) {
        self.name = name
        script = contents.joined(separator: "\n")
        deps = dependencies
        args = arguments
    }
    
    var shouldWriteFiles: Bool {
        return (try? String(contentsOf: path/"main.swift")) != script
    }
    
    func write() throws {
        //TODO we only support Swift 4.2 basically
        //TODO dependency module names can be anything so we need to parse Package.swifts for all deps to get module lists

    #if swift(>=5)
        let toolsVersion = "5.0"
    #else
        let toolsVersion = "4.2"
    #endif

        try path.mkdir(.p)
        try """
            // swift-tools-version:\(toolsVersion)
            import PackageDescription

            let pkg = Package(name: "\(name)")

            pkg.products = [
                .executable(name: "\(name)", targets: ["\(name)"])
            ]
            pkg.dependencies = [
                \(deps.packageLines)
            ]
            pkg.targets = [
                .target(name: "\(name)", dependencies: [\(deps.mainTargetDependencies)], path: ".", sources: ["main.swift"])
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

        // first arg has to be same as executable path
        let task = Process()
        task.launchPath = Path.swift.string
        task.arguments = ["build", "-Xswiftc", "-suppress-warnings"]
        task.currentDirectoryPath = path.string
      #if !os(Linux) || swift(>=5)
        task.standardOutput = task.standardError
      #else
        // setting it stderr or `nil` CRASHES ffs
        task.standardOutput = Pipe()
      #endif
        try task.launchAndWaitForSuccessfulExit()

        let exe = path/".build/debug"/name
        let args = CStringArray([exe.string] + self.args)

        guard execv(exe.string, args.cArray) != -1 else {
            throw Error.execv(executable: exe, errno: errno)
        }
        fatalError("Impossible if execv succeeded")
    }

    public enum Error: LocalizedError {
        case execv(executable: Path, errno: Int32)

        public var errorDescription: String? {
            switch self {
            case .execv(let executablePath, let errno):
                return "execv failed: \(Utility.strerror(errno)): \(executablePath)"
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



#if SWIFT_PACKAGE && DEBUG && !Xcode
extension Path {
    static var swift: Path {
        do {
            let yaml = Path.root.join(#file).parent.parent.parent.join(".build/debug.yaml")
            for line in try StreamReader(path: yaml) {
                guard let line = line.chuzzled() else { continue }
                if line.hasPrefix("executable:"), line.hasSuffix("swiftc\"") {
                    let parts = line.split(separator: ":")
                    guard parts.count == 2 else { continue }
                    return Path.root.join(parts[1].trimmingCharacters(in: .init(charactersIn: " \n\""))).parent.join("swift")
                }
            }
            fatalError("Failed to find `swift`")
        } catch {
            fatalError("\(error)")
        }
    }
}
#else
private var PATH: [Path] {
    guard let PATH = ProcessInfo.processInfo.environment["PATH"] else {
        return []
    }
    return PATH.split(separator: ":").map {
        if $0.first == "/" {
            return Path.root/$0
        } else {
            return Path.root/FileManager.default.currentDirectoryPath/$0
        }
    }
}

extension Path {
    static var swift: Path {
        for path in PATH where path.join("swift").isExecutable {
            return path/"swift"
        }

        // else use `which`
        let task = Process()
        task.launchPath = "/usr/bin/which"
        task.arguments = ["swift"]
        let str = (try? task.runSync())?.stdout.string?.chuzzled() ?? "/usr/bin/swift"
        return Path.root/str
    }
}
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
