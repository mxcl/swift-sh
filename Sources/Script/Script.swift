import StreamReader
import Foundation
import Utility
import Version
import Path

public class Script {
    let input: Input
    let deps: [ImportSpecification]
    let args: [String]

    private let inputPathHash: String?

    public var name: String {
        switch input {
        case .path(let path):
            return path.basename(dropExtension: true)
        case .string(let name, _):
            return name
        }
    }

    public var buildDirectory: Path {
        switch input {
            case .path:
                return Path.build/inputPathHash!
            case .string:
                return Path.build/name
        }
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

        // cache hash if appropriate since accessed often and involves work
        if case let Input.path(path) = input {
            self.inputPathHash = path.resolvedHash
        } else {
            self.inputPathHash = nil
        }
    }

    var depsCachePath: Path {
        return buildDirectory/"deps.json"
    }

    var depsCache: [ImportSpecification]? {
        do {
            guard depsCachePath.isFile else { throw CocoaError.error(.coderInvalidValue) }
            let data = try Data(contentsOf: depsCachePath)
            return try JSONDecoder().decode([ImportSpecification].self, from: data)
        } catch {
            return nil
        }
    }

    public func write() throws {
        //NOTE we only support Swift >= 4.2 basically
        //TODO dependency module names might not correspond the products that packages export, must parse `swift package dump-package` output

        if depsCache != deps {
            // this check because SwiftPM has to reparse the manifest if we rewrite it
            // this is noticably slow, so avoid it if possible

            var macOS: String {
                let version = ProcessInfo.processInfo.operatingSystemVersion
                return ".macOS(\"\(version.majorVersion).\(version.minorVersion)\")"
            }

            try buildDirectory.mkdir(.p)
            // we are using tools version 5.1 while we still can as >= 5.3 makes specifying deps significantly more complex
            try """
                // swift-tools-version:5.1
                import PackageDescription

                let pkg = Package(name: "\(name)")

                pkg.products = [
                    .executable(name: "\(name)", targets: ["\(name)"])
                ]
                pkg.dependencies = [
                    \(deps.packageLines)
                ]
                pkg.targets = [
                    .target(
                        name: "\(name)",
                        dependencies: [\(deps.mainTargetDependencies)],
                        path: ".",
                        exclude: ["deps.json"],
                        sources: ["main.swift"]
                    )
                ]

                #if swift(>=5) && os(macOS)
                pkg.platforms = [
                    \(macOS)
                ]
                #endif

                """.write(to: manifestPath)

            try JSONEncoder().encode(deps).write(to: depsCachePath)
        }

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

    var binaryPath: Path {
        return buildDirectory/".build/debug"/name
    }

    var manifestPath: Path {
        return buildDirectory.join("Package.swift")
    }

    var scriptChanged: Bool {
        switch input {
        case .string:
            // if we don’t have a file we can’t verify that the script is unchanged
            return true

        case .path(let path):
            guard let line = (try? StreamReader(path: manifestPath))?.pop() else { return true }
            guard let manifestVersion = line.capture(for: "//\\sswift-tools-version:\\s*(\\d+)\\.\\d+").flatMap({ Int($0) }) else { return true }

            // if the manifest version is less than 5 the script was last built with an ABI-unsafe compiler
            guard manifestVersion >= 5 else { return true }

            // if the Swift version is less than 5 we are not an ABI safe environment
            guard let swiftVersion = Float(swiftVersion), swiftVersion >= 5 else { return true }

            // compute latest mtime for script and local dependencies
            var mtimes = [path.mtime]
            for dep in deps {
                switch dep.dependencyName {
                case .local(let path):
                    for path in path.find() {
                        mtimes.append(path.mtime)
                    }
                case .url, .scp, .github:
                    ()
                }
            }
            let mtime = mtimes.compactMap({ $0 }).max()

            if let t1 = mtime, let t2 = binaryPath.mtime {
                return t1 > t2
            } else {
                return true
            }
        }
    }

    public func run() throws -> Never {
        if scriptChanged {
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
        }
        try exec(arg0: binaryPath.string, args: args)
    }
}

extension Path {
    static var swift: Path {
        if let path = Path.which("swift") {
            return path
        } else {
            let task = Process()
            task.launchPath = "/usr/bin/which"
            task.arguments = ["swift"]

            // https://github.com/mxcl/swift-sh/issues/113
            task.environment = ProcessInfo.processInfo.environment.filter{ $0.key != "SDKROOT" }

            let str = (try? task.runSync())?.stdout.string?.chuzzled() ?? "/usr/bin/swift"
            return Path.root/str
        }
    }
}

extension String {
    func chuzzled() -> String? {
        let s = trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? nil : s
    }
}

public extension Path {
    static var build: Path {
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

private extension String {
    func capture(for pattern: String) -> Substring? {
        guard let rx = try? NSRegularExpression(pattern: pattern) else { return nil }
        guard let match = rx.firstMatch(in: self) else { return nil }
        guard match.numberOfRanges >= 1 else { return nil }
        return self[match.range(at: 1)]
    }
}

let swiftVersion: String = {
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
#if swift(>=5.3)
    return "5.2"
#elseif swift(>=5.2)
    return "5.2"
#elseif swift(>=5.1)
    return "5.1"
#elseif swift(>=5)
    return "5.0"
#else
    return "4.2"
#endif
}()
