import LegibleError
import Foundation
import Command
import Path

do {
    switch CommandLine.arguments[safe: 1] {
    case "--help"?, "-h"?:
        print(CommandLine.usage)
    case "eject"?:
        let parser = try CommandLine.parse(eject: CommandLine.arguments[2...])
        try Command.eject(parser.path, force: parser.force)
#if os(macOS)
    case "edit"?:
        let path = try CommandLine.parse(edit: CommandLine.arguments[2...])
        try Command.edit(path: path)
#endif
    case "-"?:
        try Command.run(stdin, arguments: CommandLine.arguments[2...])
    default:
        let stdin_is_TTY = isatty(fileno(stdin)) == 1

        if CommandLine.arguments.count >= 2 {
            let arg1 = CommandLine.arguments[1]
            let path = Path(arg1) ?? Path.cwd/arg1
            if !stdin_is_TTY && !path.isFile {
                try Command.run(stdin, arguments: CommandLine.arguments[1...])
            } else {
                try Command.run(path, arguments: CommandLine.arguments[2...])
            }
        } else if stdin_is_TTY {
            // stdin is a terminal, show usage
            throw CommandLine.Error.invalidUsage
        } else {
            try Command.run(stdin, arguments: CommandLine.arguments[1...])
        }
    }
} catch CommandLine.Error.invalidUsage {
    fputs("""
        error: invalid usage
        \(CommandLine.usage)\n
        """, stderr)
    exit(3)
} catch {
    fputs("error: \(error.legibleLocalizedDescription)\n", stderr)
    exit(2)
}
