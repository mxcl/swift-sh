import StreamReader
import Foundation
import Utility
import Script
import Path

public func edit(path: Path) throws -> Never {
#if os(macOS)
    let input:Script.Input = .path(path)
    let reader = try StreamReader(path: path)
    var style: ExecutableTargetMainStyle = .topLevelCode
    let deps: [ImportSpecification] = try reader.compactMap { line in
        if line.contains("@main") && !(line.contains("//") || line.contains("/*")) {
            style = .mainAttribute
        }
        return try ImportSpecification(line: line, from: input)
    }
    let script = Script(for: .path(path), style: style, dependencies: deps)
    try script.write()
    try exec(arg0: "/usr/bin/swift", args: ["sh-edit", path.string, script.buildDirectory.string])
#else
    throw CommandLine.Error.invalidUsage
#endif
}
