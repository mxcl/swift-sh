import Foundation
import Command
import Library

do {
    guard CommandLine.arguments.count > 1 else {
        throw CommandLine.Error.invalidUsage
    }
    switch CommandLine.arguments[1] {
    case "--help", "-h":
        print(CommandLine.usage)
    case "eject":
        let parser = try CommandLine.parse(eject: CommandLine.arguments[2...])
        try Command.eject(parser.path, force: parser.force)
    default:
        guard CommandLine.arguments.count >= 2 else { throw CommandLine.Error.invalidUsage }
        let arg1 = CommandLine.arguments[1]
        let path = Path(absolute: arg1) ?? Path.cwd/arg1
        let args = CommandLine.arguments.dropFirst(2)
        try Command.run(path, arguments: args)
    }
} catch CommandLine.Error.invalidUsage {
    fputs("error: invalid usage\n", stderr)
    fputs(CommandLine.usage, stderr)
    exit(3)
} catch {
    fputs("error: \(error.legibleDescription)\n", stderr)
    exit(2)
}
