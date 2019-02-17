import Foundation
import Utility
import Script
import Path

public func edit(path: Path) throws -> Never {
    let reader = try StreamReader(path: path)
    let deps = reader.compactMap(ImportSpecification.init)

    let script = Script(for: .path(path), dependencies: deps)
    try script.write()

#if !os(Linux)
    //TODO only regenerate if necessary
    let task = Process()
    task.launchPath = "/usr/bin/swift"
    task.arguments = ["package", "generate-xcodeproj"]
    task.currentDirectoryPath = script.buildDirectory.string
    try task.launchAndWaitForSuccessfulExit()

    let xcodeproj = script.buildDirectory/"\(script.name).xcodeproj"
    try exec(arg0: Path.root.usr.bin.open, args: [xcodeproj.string])
#else
    guard let editor = ProcessInfo.processInfo.environment["EDITOR"] else {
        fatalError("EDITOR undefined")
    }
    guard let path = Path(editor) ?? Path.which(editor) else {
        fatalError("EDITOR not in PATH")
    }
    try exec(arg0: path, args: [script.mainSwift.string])
#endif
}

public extension CommandLine {
    static func parse<T>(edit args: T) throws -> Path where T: Collection, T.Element == String, T.Index == Int {
        guard args.count == 1 else {
            throw CommandLine.Error.invalidUsage
        }
        let arg = args.first!
        return Path(arg) ?? Path.cwd/arg
    }
}
