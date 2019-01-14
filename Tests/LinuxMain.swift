import XCTest

@testable import ShwiftyTests

XCTMain([
    testCase(IntegrationTests.allTests),
    testCase(UnitTests.allTests)
])
