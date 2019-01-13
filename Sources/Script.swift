import Foundation

public class Script {
    let name: String
    let deps: [(String, Constraint)]
    let script: String

    var path: Path {
      #if os(macOS)
        return Path.home/"Library/Developer/swift-sh.cache"/name
      #else
        if let path = ProcessInfo.processInfo.environment["XDG_CACHE_HOME"] {
            return Path.root/path/"swift-sh"
        } else {
            return Path.home/".cache/swift-sh"
        }
      #endif
    }

    public init(name: String, contents: [String], dependencies: [(String, Constraint)]) {
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

        var depNames: String {
            return deps.map {
                $0.0.split(separator: "/")[1]
            }.map { """
                "\($0)"
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
                \(deps.map(packageLine).joined(separator: ",\n    "))
            ]
            pkg.targets = [
                .target(name: "\(name)", dependencies: [
                    \(depNames)
                ], path: ".", sources: ["main.swift"])
            ]

            """.write(to: path/"Package.swift")

        try script.write(to: path/"main.swift")
	}

    public func run() throws {		
		if shouldWriteFiles {
	        // don‘t write `main.swift` if would be identical
	        // ∵ prevents swift-build recognizing a null-build
	        // ie. prevents unecessary rebuild of our script
			try write()
		}

        let task = Process()
        task.launchPath = "/usr/bin/swift"
        task.arguments = ["run"]
        task.currentDirectoryPath = path.string
        if #available(OSX 10.13, *) {
            try task.run()
        } else {
            task.launch()
        }
        task.waitUntilExit()
    }
}

private func packageLine(depName: String, constraint: Constraint) -> String {
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
    if let url = URL(string: depName), url.scheme != nil {
        urlstr = depName
    } else {
        urlstr = "https://github.com/\(depName).git"
    }
    return """
        .package(url: "\(urlstr)", \(requirement))
        """
}
