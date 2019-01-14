@testable import Shwifty
import XCTest

var shebang: String {
#if Xcode
    return Bundle(for: IntegrationTests.self).path.parent.join("exe").string
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
            #!\(shebang)
            import Foundation
            import Result  // @antitypical ~> 4.1

            print(Result<Int, CocoaError>.success(3))
            """)
    }

    func testNamingMismatch() {
        XCTAssertEqual("Promise(3)", exec: """
            #!\(shebang)
            import PMKFoundation  // PromiseKit/Foundation ~> 3
            import PromiseKit

            print(Promise.value(3))
            """)
    }

    func testTestableImport() {
        XCTAssertEqual(".success(4)", exec: """
            #!\(shebang)
            import Foundation
            @testable import Result  // @antitypical ~> 4.1

            print(Result<Int, CocoaError>.success(4))
            """)
    }

    func testTestableFullySpecifiedURL() {
        XCTAssertEqual(".success(5)", exec: """
            #!\(shebang)
            import Foundation
            @testable import Result  // https://github.com/antitypical/Result ~> 4.1

            print(Result<Int, CocoaError>.success(5))
            """)
    }

    func testNSHipsterExample() {
        XCTAssertRuns(exec: """
            #!\(shebang)
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
}

func XCTAssertRuns(exec: String, line: UInt = #line) {
    do {
        try Path.mktemp { tmpdir -> Void in
            let file = tmpdir.join("foo\(line).swift")
            try exec.write(to: file)
            try file.chmod(0o0500)
            try Process.system(file.string)
        }
    } catch {
        XCTFail("\(error)", line: line)
    }
}

func XCTAssertEqual(_ expected: String, exec: String, line: UInt = #line) {
    do {
        try Path.mktemp { tmpdir -> Void in
            let file = tmpdir.join("foo\(line).swift")
            try exec.write(to: file)
            try file.chmod(0o0500)
            
            let task = Process()
            task.launchPath = file.string
            let stdout = try task.runSync().stdout.string?.chuzzled()
            XCTAssertEqual(stdout, expected, line: line)
        }
    } catch {
        XCTFail("\(error)", line: line)
    }
}
