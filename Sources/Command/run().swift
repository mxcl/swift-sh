import struct Foundation.Data
import Library
import Path
import ImportSpecification

#if !os(Linux)
import struct Darwin.FILE
#else
import struct Glibc.FILE
#endif

//TODO
// should we update packages? maybe in background when running scripts

private func run<T>(reader: StreamReader, name: String, arguments: T) throws -> Never where T: Collection, T.Element == String {
    var tee = [String]()
    for (index, line) in reader.enumerated() {
        if index == 0, line.hasPrefix("#!") { continue }
        tee.append(line)
    }
    
    let deps = try ImportSpecification.parse(tee.joined(separator: "\n"))

    let script = Script(name: name, contents: tee, dependencies: deps, arguments: Array(arguments))
    try script.run()
}

public func run<T>(_ file: UnsafeMutablePointer<FILE>, arguments: T) throws -> Never where T: Collection, T.Element == String {
    try run(reader: StreamReader(file: file), name: "<stdin>", arguments: arguments)
}

public func run<T>(_ script: Path, arguments: T) throws -> Never where T: Collection, T.Element == String {
    let name = script.basename(dropExtension: true)
    let reader = try StreamReader(path: script)
    try run(reader: reader, name: name, arguments: arguments)
}
