import struct Foundation.Data
import Utility
import Script
import Path

#if !os(Linux)
import struct Darwin.FILE
#else
import struct Glibc.FILE
#endif

//TODO
// should we update packages? maybe in background when running scripts

private func run<T>(reader: StreamReader, input: Input, arguments: T) throws -> Never where T: Collection, T.Element == String {
    // We are not a thorough parser, and that would be inefficient.
    // Since any line starting with import that is not in a comment
    // must be at file-scope or it is invalid Swift we just look
    // for that
    //TODO if we are inside a comment block, know that, and wait for
    // end of comment block.
    //TODO may need to parse `#if os()` etc. too, which may mean we
    // should just use SourceKitten and do a proper parse
    //TODO well also could have an import structure where is split
    // over multiple lines with semicolons. So maybe parser?

    var deps = [ImportSpecification]()
    var lines = [String]()

    for (index, line) in reader.enumerated() {
        if index == 0, line.hasPrefix("#!") {
            lines.append("// shebang removed")  // keep line numbers in sync
            continue
        }
        if let result = ImportSpecification(line: line) {
            deps.append(result)
        }
        switch input {
        case .stdin, .namedPipe:
            lines.append(line)
        case .file:
            break
        }
    }

    var transformedInput: Script.Input {
        switch input {
        case .stdin, .namedPipe:
            return .string(name: input.name, content: lines.joined(separator: "\n"))
        case .file(let path):
            return .path(path)
        }
    }

    let script = Script(for: transformedInput, dependencies: deps, arguments: Array(arguments))
    try script.run()
}

public func run<T>(_ file: UnsafeMutablePointer<FILE>, arguments: T) throws -> Never where T: Collection, T.Element == String {
    try run(reader: StreamReader(file: file), input: .stdin, arguments: arguments)
}

public func run<T>(_ script: Path, arguments: T) throws -> Never where T: Collection, T.Element == String {
    let reader: StreamReader
    let input: Input
    if let namedPipe = script.namedPipe {
        reader = StreamReader(file: namedPipe)
        input = .namedPipe(namedPipe)
    } else {
        reader = try StreamReader(path: script)
        input = .file(script)
    }
    try run(reader: reader, input: input, arguments: arguments)
}
