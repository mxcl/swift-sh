import Foundation
import Path

//MARK: CommandLine.usage

public extension CommandLine {
    static var usage: String {
        var rv = """
            swift sh <script> [arguments]
            swift sh eject <script> [-f|--force]
            swift sh --clean-cache [-C] [<script>]
            swift sh editor <script>
            """
      #if os(macOS)
        rv += "\nswift sh edit <script>"
      #endif
        return rv
    }

    enum Error: LocalizedError {
        case invalidUsage

        public var errorDescription: String? {
            switch self {
            case .invalidUsage:
                return CommandLine.usage
            }
        }
    }
}

//MARK: ArgumentsParser

private struct ArgumentsParser {
    let untarnishedArguments: ArraySlice<String>
    private var args: [String]

    var isEmpty: Bool {
        return args.isEmpty
    }

    var count: Int {
        return args.count
    }

    init<S: Collection>(args: S) where S.Element == String, S.Index == Int {
        self.args = Array(args)
        self.untarnishedArguments = ArraySlice(args)
    }

    mutating func flag(long: String, short: String? = nil) -> Bool {
        for (index, arg) in args.enumerated() where arg == long || arg == short {
            args.remove(at: index)
            return true
        }
        return false
    }

    mutating func pop<T>(_ body: (String) -> T) -> T? {
        guard let arg = args.popLast() else { return nil }
        return body(arg)
    }

    mutating func pop() -> String? {
        return args.popLast()
    }

    mutating func converts<T>(to: (String) throws -> T?) rethrows -> T? {
        for (index, arg) in args.enumerated() {
            if let foo = try to(arg) {
                args.remove(at: index)
                return foo
            }
        }
        return nil
    }

    mutating func command() -> String? {
        guard let arg = args.first else {
            return nil
        }
        args.remove(at: 0)
        return arg
    }

    var remainder: ArraySlice<String> {
        return args[0...]
    }

    func contains(_ string: String) -> Bool {
        return args.contains(string)
    }
}

//MARK: Mode

public enum Mode {
    case run(RunType, args: ArraySlice<String>)
    case eject(Path, force: Bool)
    case edit(Path)
    case editor(Path)
    case clean(Path?)
    case help

    public enum RunType {
        case stdin
        case file(Path)
    }

    public init(for args: [String], isTTY: Bool) throws  {
        var parser = ArgumentsParser(args: Array(args.dropFirst()))
        let command = parser.command()

        switch command {
        case "eject"?:
            let force = parser.flag(long: "--force", short: "-f")
            guard let path = parser.pop({ Path($0) ?? Path.cwd/$0 }) else {
                throw CommandLine.Error.invalidUsage
            }
            guard parser.isEmpty else {
                throw CommandLine.Error.invalidUsage
            }
            self = .eject(path, force: force)
        case "edit"?:
            guard let arg1 = parser.pop() else {
                throw CommandLine.Error.invalidUsage
            }
            guard parser.isEmpty else {
                throw CommandLine.Error.invalidUsage
            }
            self = .edit(Path(arg1) ?? Path.cwd/arg1)
        case "editor"?:
            guard let arg1 = parser.pop() else {
                throw CommandLine.Error.invalidUsage
            }
            guard parser.isEmpty else {
                throw CommandLine.Error.invalidUsage
            }
            self = .editor(Path(arg1) ?? Path.cwd/arg1)
        case "-"?, "--"?:
            self = .run(.stdin, args: parser.remainder)
        case "--help"?, "-h"?:
            self = .help
        case "--clean-cache", "-C":
            if let arg1 = parser.pop() {
                self = .clean(Path(arg1) ?? Path.cwd/arg1)
            } else {
                self = .clean(nil)
            }
        case let arg1?:
            let path = Path(arg1) ?? Path.cwd/arg1

            if isTTY, arg1 == "--force" || arg1 == "-f", parser.contains("eject") {

                //TODO more specific error
                //NOTE done so that misordering flags that only apply to `eject` doesn’t attempt
                // to run a script called `--force`
                throw CommandLine.Error.invalidUsage

            } else if isTTY || path.isFile {
                // user wants to execute an actual script file
                self = .run(.file(path), args: parser.remainder)
            } else {
                // the script is being piped via stdin
                self = .run(.stdin, args: parser.untarnishedArguments)
            }
        case nil:
            if isTTY {
                throw CommandLine.Error.invalidUsage
            } else {
                self = .run(.stdin, args: parser.remainder)
            }
        }
    }
}
