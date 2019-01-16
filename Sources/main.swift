import Foundation
import Command
import Library

guard CommandLine.arguments.count == 2 else {
    fputs("usage: swift sh PATH\n", stderr)
    fputs("usage: swift sh eject\n", stderr)
    exit(1)
}

do {
    switch CommandLine.arguments[1] {
    case "eject":
        try Command.eject()
    default:
        try Command.run(CommandLine.path(at: 1))
    }
} catch let error as CommandLineError {
    fputs("error: \(error.stderrString)\n", stderr)
    exit(2)
}
