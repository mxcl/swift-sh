import StreamReader
import Foundation
import Utility
import Script
import Path

public func editor(path: Path) throws -> Never {
    let input:Script.Input = .path(path)
    let deps = try StreamReader(path: path).compactMap { try ImportSpecification(line: $0, from: input) }
    let script = Script(for: .path(path), dependencies: deps)
    try script.write()

    guard let editor = ProcessInfo.processInfo.environment["EDITOR"] else {
        fatalError("EDITOR undefined")
    }
    guard let path = Path(editor) ?? Path.which(editor) else {
        fatalError("EDITOR not in PATH")
    }
    chdir(script.buildDirectory.string)
    try exec(arg0: path.string, args: [script.mainSwift.string])
}
