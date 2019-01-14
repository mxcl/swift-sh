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

#if os(Linux)
extension IntegrationTests {
    static var allTests: [(String, (IntegrationTests) -> () throws -> Void)] {
        return [
            ("testConventional", testConventional),
            ("testNamingMismatch", testNamingMismatch)
        ]
    }
}
#endif
