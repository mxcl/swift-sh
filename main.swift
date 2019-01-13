import Foundation
import Shwifty

//TODO
// should we update packages? maybe in background when running scripts

guard ProcessInfo.processInfo.arguments.count == 2 else {
    fputs("usage: swift sh PATH\n", stderr)
    exit(1)
}

let scriptPath = ProcessInfo.processInfo.arguments[1]
let name = Path.root.join(scriptPath).basename(dropExtension: true)

guard let reader = StreamReader(path: scriptPath) else {
    fputs("error: could not open \(scriptPath)\n", stderr)
    exit(2)
}

var tee = [String]()
var deps = [(String, Constraint)]()

// We are not a thorough parser, and that would be inefficient.
// Since any line starting with import that is not in a comment
// must be at file-scope or it is invalid Swift we just look
// for that
//TODO if we are inside a comment block, know that, and wait for
// end of comment block.
//TODO may need to parse `#if os()` etc. too, which may mean we
// should just use SourceKitten and do a proper parse

for (index, line) in reader.enumerated() {
    if index == 0, line.hasPrefix("#!") { continue }

    let trimmed = line.trimmingCharacters(in: .whitespaces)

    if trimmed.hasPrefix("import"), let parse = Shwifty.parse(trimmed) {
        deps.append(parse)
    }

    tee.append(line)
}

let script = Script(name: name, contents: tee, dependencies: deps)
try script.run()
