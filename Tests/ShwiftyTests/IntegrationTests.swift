@testable import Library
import XCTest

var shebang: String {
#if Xcode
    return Bundle(for: IntegrationTests.self).path.parent.join("Executable").string
#elseif os(Linux)
    // Bundle(for:) is unimplemented
    return Path.root.join(#file).parent.parent.parent.join(".build/debug/swift-sh").string
#else
    return Bundle(for: IntegrationTests.self).path.parent.join("swift-sh").string
#endif
}

class IntegrationTests: XCTestCase {
    func testConventional() {
        XCTAssertEqual(".success(3)", exec: """
            import Foundation
            import Result  // @antitypical ~> 4.1

            print(Result<Int, CocoaError>.success(3))
            """)
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

private func write(script: String, line: UInt = #line, body: (Path) throws -> Void) throws {
    try Path.mktemp { tmpdir -> Void in
        let file = tmpdir.join("dev.mxcl.swift-sh-tests-\(line).swift")
        try "#!\(shebang)\n\(script)".write(to: file)
        try file.chmod(0o0500)
        try body(file)
    }
}

private func XCTAssertRuns(exec: String, line: UInt = #line) {
    do {
        try write(script: exec) { file in
            try Process.system(file.string)
        }
    } catch {
        XCTFail("\(error)", line: line)
    }
}

private func XCTAssertEqual(_ expected: String, exec: String, line: UInt = #line) {
    do {
        try write(script: exec) { file in
            let task = Process()
            task.launchPath = file.string
            let stdout = try task.runSync().stdout.string?.chuzzled()
            XCTAssertEqual(stdout, expected, line: line)
        }
    } catch {
        XCTFail("\(error)", line: line)
    }
}
