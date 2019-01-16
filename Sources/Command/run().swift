import Library

//TODO
// should we update packages? maybe in background when running scripts

public func run(_ script: Path) throws -> Never {
    let name = script.basename(dropExtension: true)
    let reader = try StreamReader(path: script)
    var tee = [String]()
    var deps = [ImportSpecification]()

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

    for (index, line) in reader.enumerated() {
        if index == 0, line.hasPrefix("#!") { continue }

        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("import") || trimmed.hasPrefix("@testable"), let parse = Library.parse(trimmed) {
            deps.append(parse)
        }

        tee.append(line)
    }

    let script = Script(name: name, contents: tee, dependencies: deps)
    try script.run()
}
