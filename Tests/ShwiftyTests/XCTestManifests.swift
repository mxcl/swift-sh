import XCTest

extension IntegrationTests {
    static let __allTests = [
        ("testConventional", testConventional),
        ("testNamingMismatch", testNamingMismatch),
        ("testNSHipsterExample", testNSHipsterExample),
        ("testTestableFullySpecifiedURL", testTestableFullySpecifiedURL),
        ("testTestableImport", testTestableImport),
    ]
}

extension UnitTests {
    static let __allTests = [
        ("testCanDoSpecifiedImports", testCanDoSpecifiedImports),
        ("testCanOverrideImportName", testCanOverrideImportName),
        ("testCanProvideFullURL", testCanProvideFullURL),
        ("testCanUseTestable", testCanUseTestable),
        ("testExact", testExact),
        ("testMinimalSpaces", testMinimalSpaces),
        ("testMoreSpaces", testMoreSpaces),
        ("testWigglyArrow", testWigglyArrow),
    ]
}

#if !os(macOS)
public func __allTests() -> [XCTestCaseEntry] {
    return [
        testCase(IntegrationTests.__allTests),
        testCase(UnitTests.__allTests),
    ]
}
#endif
