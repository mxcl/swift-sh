import Foundation
import Utility
import Script
import Path

#if os(macOS)
public func edit(path: Path) throws -> Never {
    let deps = try StreamReader(path: path).compactMap(ImportSpecification.init)
    let script = Script(for: .path(path), dependencies: deps)
    try script.write()
    try exec(arg0: "/usr/bin/swift", args: ["sh-edit", path.string, script.buildDirectory.string])
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
#endif
