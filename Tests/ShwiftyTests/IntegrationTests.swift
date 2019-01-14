@testable import Shwifty
import XCTest

var shebang: String {
#if Xcode
    return Bundle(for: IntegrationTests.self).path.parent.join("exe").string
#else
    return Bundle(for: IntegrationTests.self).path.parent.join("swift-sh").string
#endif
}

class IntegrationTests: XCTestCase {
    func test() {
        XCTAssertEqual(".success(3)", exec: """
            #!\(shebang)
            import Foundation
            import Result  // @antitypical ~> 4.1

            print(Result<Int, CocoaError>.success(3))
            """)
    }
}

func XCTAssertEqual(_ out: String, exec: String, line: UInt = #line) {
    do {
        try Path.mktemp { tmpdir -> Void in
            let file = tmpdir.join("foo.swift")
            try exec.write(to: file)
            try file.chmod(0o0500)

            let pipe = Pipe()
            let task = Process()
            task.launchPath = file.string
            task.standardOutput = pipe
            task.launch()
            task.waitUntilExit()

            enum E: Error {
                case executionFailed
            }

            guard task.terminationReason == .exit, task.terminationStatus == 0 else {
                throw E.executionFailed
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            XCTAssertEqual(String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), out, line: line)
        }
    } catch {
        XCTFail("\(error)", line: line)
    }
}
