import Foundation
import Utility
import Path

public class Script {
    let input: Input
    let deps: [ImportSpecification]
    let args: [String]

    public var name: String {
        switch input {
        case .path(let path):
            return path.basename(dropExtension: true)
        case .string(let name, _):
            return name
        }
    }

    public var buildDirectory: Path {
        return Path.selfCache/name
    }

    public var mainSwift: Path {
        return buildDirectory/"main.swift"
    }

    public enum Input {
        case path(Path)
        case string(name: String, content: String)
    }

    public init(for: Input, dependencies: [ImportSpecification], arguments: [String] = []) {
        input = `for`
        deps = dependencies
        args = arguments
    }

    public func write() throws {
        //TODO we only support Swift 4.2 basically
        //TODO dependency module names can be anything so we need to parse Package.swifts for all deps to get module lists

        try buildDirectory.mkdir(.p)
        try """
            // swift-tools-version:\(swiftVersion)
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

            """.write(to: buildDirectory/"Package.swift")

        switch input {
        case .path(let userPath):
            func mklink() throws { try userPath.symlink(as: mainSwift) }

            if let linkdst = try? mainSwift.readlink(), linkdst != userPath {
                try mainSwift.delete()
                try mklink()
            } else if !mainSwift.exists {
                try mklink()
            }
        case .string(_, let contents):
            if let currentContents = try? String(contentsOf: mainSwift), currentContents == contents { break }
            try contents.write(to: mainSwift)
        }
    }

    public func run() throws -> Never {

        try write()

        // first arg has to be same as executable path
        let task = Process()
        task.launchPath = Path.swift.string
        task.arguments = ["build", "-Xswiftc", "-suppress-warnings"]
        task.currentDirectoryPath = buildDirectory.string
      #if !os(Linux)
        task.standardOutput = task.standardError
      #else
        // setting it stderr or `nil` CRASHES ffs
        task.standardOutput = Pipe()
      #endif
        try task.launchAndWaitForSuccessfulExit()

        try exec(arg0: buildDirectory/".build/debug"/name, args: args)
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
extension Path {
    static var swift: Path {
        if let path = Path.which("swift") {
            return path
        } else {
            let task = Process()
            task.launchPath = "/usr/bin/which"
            task.arguments = ["swift"]
            let str = (try? task.runSync())?.stdout.string?.chuzzled() ?? "/usr/bin/swift"
            return Path.root/str
        }
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

var swiftVersion: String {
    do {
        let task = Process()
        task.launchPath = Path.swift.string
        task.arguments = ["--version"]
        if let input = try task.runSync(.stdout).string {
            let range = input.range(of: "Swift version \\d+\\.\\d+", options: .regularExpression)!
            if let found = input[range].split(separator: " ").last {
                return String(found)
            }
        }
    } catch {
        assert(false)  // shouldn't happen during testing so let’s catch it
    }
#if swift(>=5)
    return "5.0"
#else
    return "4.2"
#endif
}

