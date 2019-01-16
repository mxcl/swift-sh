@testable import Library
import XCTest

class LibraryTests: XCTestCase {
    func testStrerror() {
        //NOTE does this get localized? If fails for you please open a ticket! https://github.com/mxcl/swift-sh/issues
        XCTAssertEqual(strerror(ERANGE), "Result too large (34)")
    }
}
