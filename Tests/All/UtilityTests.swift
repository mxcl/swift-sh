@testable import Utility
import XCTest
import Path

class LibraryTests: XCTestCase {
    func testStrerror() {
    #if os(macOS)
        // If fails for you please open a ticket! https://github.com/mxcl/swift-sh/issues/new
        XCTAssertEqual(strerror(ERANGE), "Result too large (34)")
    #else
        XCTAssert(strerror(ERANGE).hasSuffix("(34)"))
    #endif
    }
}
