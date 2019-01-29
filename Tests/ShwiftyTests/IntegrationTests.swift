@testable import Command
@testable import Library
import XCTest
import Path

class RunIntegrationTests: XCTestCase {
    override class func setUp() {
        guard Path.selfCache.isDirectory else { return }
        for entry in try! Path.selfCache.ls() where entry.kind == .directory && entry.path.basename().hasPrefix(scriptBaseName) {
            try! entry.path.delete()
        }
    }

    func testConventional() {
        XCTAssertEqual(.resultScriptOutput, exec: .resultScript)
    }

    func testNamingMismatch() {
        XCTAssertEqual("Promise(3)", exec: """
            import PMKFoundation  // PromiseKit/Foundation ~> 3
            import PromiseKit

            print(Promise.value(3))
            """)
    }

    func testTestableImport() {
        XCTAssertEqual(".success(4)", exec: """
            import Foundation
            @testable import Result  // @antitypical ~> 4.1

            print(Result<Int, CocoaError>.success(4))
            """)
    }

    func testTestableFullySpecifiedURL() {
        XCTAssertEqual(".success(5)", exec: """
            import Foundation
            @testable import Result  // https://github.com/antitypical/Result ~> 4.1

            print(Result<Int, CocoaError>.success(5))
            """)
    }

    func testStandardInputCanBeUsedInScript() throws {
        let stdin = Pipe()
        let stdout = Pipe()
        let task = Process()
        task.standardInput = stdin
        task.standardOutput = stdout

        let hello = "Hello\n".data(using: .utf8)!

        try write(script: "print(readLine()!)") { file in
            task.launchPath = file.string
            try task.go()
            stdin.fileHandleForWriting.write(hello)
            task.waitUntilExit()

            let got = stdout.fileHandleForReading.readDataToEndOfFile()

            XCTAssertEqual(got, hello)
        }
    }

    func testArguments() {
        XCTAssertEqual(".success(3)", exec: """
            import Foundation
            @testable import Result  // https://github.com/antitypical/Result ~> 4.1

            let arg = CommandLine.arguments[1]
            print(Result<Int, CocoaError>.success(Int(arg)!))
            """, arg: "3")
    }

    func testNSHipsterExample() {
        XCTAssertRuns(exec: """
            import DeckOfPlayingCards  // @NSHipster ~> 4.0.0
            import PlayingCard
            import Cycle  // @NSHipster == bb11e28

            class Player {
                var name: String
                var hand: [PlayingCard] = []

                init(name: String) {
                    self.name = name
                }
            }

            extension Player: CustomStringConvertible {
                var description: String {
                    var description = "\\(name):"

                    let cardsBySuit = Dictionary(grouping: hand) { $0.suit }
                    for (suit, cards) in cardsBySuit.sorted(by: { $0.0 > $1.0 }) {
                        description += "\\t\\(suit) "
                        description += cards.sorted(by: >)
                                            .map{ "\\($0.rank)" }
                                            .joined(separator: " ")
                        description += "\\n"
                    }

                    return description
                }
            }

            var deck = Deck.standard52CardDeck()
            deck.shuffle()

            var north = Player(name: "North")
            var west = Player(name: "West")
            var east = Player(name: "East")
            var south = Player(name: "South")

            let players = [north, east, west, south]
            var round = players.cycled()

            while let card = deck.deal(), let player = round.next() {
                player.hand.append(card)
            }

            for player in players {
                print(player)
            }
            """)
    }

    func testRelativePath() throws {
        try write(script: "print(123)") { file in
            let task = Process()
            task.launchPath = "/bin/sh"
            task.arguments = ["-c", "./\(file.basename())"]
            task.currentDirectoryPath = file.parent.string
            let stdout = try task.runSync().stdout.string?.chuzzled()
            XCTAssertEqual(stdout, "123")
        }
    }
}

class EjectIntegrationTests: XCTestCase {
    func testForce() throws {

        func go(file: Path, insertionIndex: Int, flag: String) throws {
            var args = [file.string]
            args.insert(flag, at: insertionIndex)

            let task = Process()
            task.launchPath = shebang
            task.arguments = ["eject"] + args

            try Path.mktemp { tmpdir in
                task.currentDirectoryPath = tmpdir.string
                try task.go()
                task.waitUntilExit()

                let name = file.basename(dropExtension: true)
                let d = file.parent.join(name.capitalized)

                let memo = "flag: `\(flag)`, at: \(insertionIndex)"

                XCTAssertFalse(file.exists, memo)
                XCTAssert(d.isDirectory, memo)
                XCTAssert(d.join("Package.swift").isFile, memo)
                XCTAssert(d.join("Sources").isDirectory, memo)
                XCTAssert(d.join("Sources/main.swift").isFile, memo)

                let build = Process()
                build.launchPath = Path.swift.string
                build.arguments = ["run"]
                build.currentDirectoryPath = d.string
                let out = try build.runSync().stdout.string
                XCTAssertEqual(out, String.resultScriptOutput)
            }
        }

        for flag in ["-f", "--force"] {
            for insertionIndex in 0...1 {
                try write(script: .resultScript) { file in
                    try go(file: file, insertionIndex: insertionIndex, flag: flag)
                }
            }
        }
    }

    func testFilenameDirectoryClash() throws {
        // if the file is `foo` and we will create a package `Foo` in the same directory
        // this is a filename clash on macOS with its case insensitive filesystem
        // and we still should *work*
        //TODO should check the filesystem is insenstive to verify test is working

        try Path.mktemp { tmpdir -> Void in
            let file = tmpdir/"foo"
            try """
                #!/usr/bin/swift sh

                print(123)
                """.write(to: file)

            let task = Process()
            task.launchPath = shebang
            task.arguments = ["eject", file.string]
            try task.go()
            task.waitUntilExit()

            let d = tmpdir/"Foo"

            XCTAssertFalse(file.isFile)
            XCTAssert(d.isDirectory)
            XCTAssert(d.join("Package.swift").isFile)
            XCTAssert(d.join("Sources").isDirectory)
            XCTAssert(d.join("Sources/main.swift").isFile)
        }
    }

    func testRelativePath() throws {
        try Path.mktemp { tmpdir -> Void in
            let file = tmpdir/"foo"
            try "#!/usr/bin/swift sh".write(to: file)

            let task = Process()
            task.launchPath = shebang
            task.arguments = ["eject", file.basename()]
            task.currentDirectoryPath = tmpdir.string
            try task.go()
            task.waitUntilExit()

            let d = tmpdir/"Foo"

            XCTAssertFalse(file.isFile)
            XCTAssert(d.isDirectory)
            XCTAssert(d.join("Package.swift").isFile)
            XCTAssert(d.join("Sources").isDirectory)
            XCTAssert(d.join("Sources/main.swift").isFile)
        }
    }


    func testFailsIfNotScript() throws {
        try Path.mktemp { tmpdir -> Void in
            let file = tmpdir/"foo"
            try "foo".write(to: file)
            let pipe = Pipe()
            let task = Process()
            task.launchPath = shebang
            task.arguments = ["eject", file.string]
            task.standardError = pipe
            try task.go()
            task.waitUntilExit()

            let stderr = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.chuzzled()

            XCTAssertEqual(task.terminationStatus, 2)
            XCTAssertEqual(stderr, "error: " + EjectError.notScript.errorDescription!)
        }
    }
}

private func write(script: String, line: UInt = #line, body: (Path) throws -> Void) throws {
    try Path.mktemp { tmpdir -> Void in
        let file = tmpdir.join("\(scriptBaseName)-\(line).swift")
        try "#!\(shebang)\n\(script)".write(to: file)
        try file.chmod(0o0500)
        try body(file)
    }
}

private func XCTAssertRuns(exec: String, line: UInt = #line) {
    do {
        try write(script: exec, line: line) { file in
            try Process.system(file.string)
        }
    } catch {
        XCTFail("\(error)", line: line)
    }
}

private func XCTAssertEqual(_ expected: String, exec: String, arg: String? = nil, line: UInt = #line) {
    do {
        try write(script: exec, line: line) { file in
            let task = Process()
            task.launchPath = file.string
            task.arguments = arg.map{ [$0] } ?? []
            let stdout = try task.runSync().stdout.string?.chuzzled()
            XCTAssertEqual(stdout, expected, line: line)
        }
    } catch {
        XCTFail("\(error)", line: line)
    }
}

private var shebang: String {
#if Xcode
    return Bundle(for: RunIntegrationTests.self).path.parent.join("Executable").string
#elseif os(Linux)
    // Bundle(for:) is unimplemented
    return Path.root.join(#file).parent.parent.parent.join(".build/debug/swift-sh").string
#else
    return Bundle(for: RunIntegrationTests.self).path.parent.join("swift-sh").string
#endif
}

private extension String {
    static var resultScript: String {
        return """
        import Foundation
        import Result  // @antitypical ~> 4.1

        print(Result<Int, CocoaError>.success(3))
        """
    }

    static var resultScriptOutput: String {
        return ".success(3)"
    }
}

private let scriptBaseName = "dev.mxcl.swift-sh-tests"
