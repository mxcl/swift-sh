import StreamReader
import Foundation
import Utility
import Script
import Path

public func editor(path: Path) throws -> Never {
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

    guard let editor = ProcessInfo.processInfo.environment["EDITOR"] else {
        fatalError("EDITOR undefined")
    }
    guard let path = Path(editor) ?? Path.which(editor) else {
        fatalError("EDITOR not in PATH")
    }
    chdir(script.buildDirectory.string)
    try exec(arg0: path.string, args: [script.mainSwift.string])
}
