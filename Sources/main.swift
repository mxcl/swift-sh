import Foundation
import Command
import Library
import Path

do {
    switch CommandLine.arguments[safe: 1] {
    case "--help"?, "-h"?:
        print(CommandLine.usage)
    case "eject"?:
        let parser = try CommandLine.parse(eject: CommandLine.arguments[2...])
        try Command.eject(parser.path, force: parser.force)
    case "-"?:
        try Command.run(stdin, arguments: CommandLine.arguments.dropFirst(2))
    default:
        if CommandLine.arguments.count >= 2 {
            let arg1 = CommandLine.arguments[1]
            let path = Path(arg1) ?? Path.cwd/arg1
            let args = CommandLine.arguments.dropFirst(2)
            try Command.run(path, arguments: args)
        } else if isatty(fileno(stdin)) == 1 {
            // stdin is a terminal, show usage
            throw CommandLine.Error.invalidUsage
        } else {
            try Command.run(stdin, arguments: CommandLine.arguments.dropFirst())
        }
    }
} catch CommandLine.Error.invalidUsage {
    fputs("error: invalid usage\n", stderr)
    fputs(CommandLine.usage, stderr)
    exit(3)
} catch {
    fputs("error: \(error.legibleDescription)\n", stderr)
    exit(2)
}
