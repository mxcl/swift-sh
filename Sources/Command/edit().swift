import StreamReader
import Foundation
import Utility
import Script
import Path

public func edit(path: Path) throws -> Never {
#if os(macOS)
    let input:Script.Input = .path(path)
    let deps = try StreamReader(path: path).compactMap { try ImportSpecification(line: $0, from: input) }
    let script = Script(for: .path(path), dependencies: deps)
    try script.write()
    try exec(arg0: "/usr/bin/swift", args: ["sh-edit", path.string, script.buildDirectory.string])
#else
    throw CommandLine.Error.invalidUsage
#endif
}
