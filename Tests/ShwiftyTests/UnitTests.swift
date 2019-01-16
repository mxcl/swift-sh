@testable import Library
import XCTest

class UnitTests: XCTestCase {
    func testWigglyArrow() {
        let a = parse("import Foo // @mxcl ~> 1.0")
        XCTAssertEqual(a?.dependencyName, "mxcl/Foo")
        XCTAssertEqual(a?.constraint, .upToNextMajor(from: .one))
        XCTAssertEqual(a?.importName, "Foo")
    }

    func testExact() {
        let a = parse("import Foo // @mxcl == 1.0")
        XCTAssertEqual(a?.dependencyName, "mxcl/Foo")
        XCTAssertEqual(a?.constraint, .exact(.one))
        XCTAssertEqual(a?.importName, "Foo")
    }

    func testMoreSpaces() {
        let b = parse("import    Foo       //     @mxcl    ~>      1.0")
        XCTAssertEqual(b?.dependencyName, "mxcl/Foo")
        XCTAssertEqual(b?.constraint, .upToNextMajor(from: .one))
        XCTAssertEqual(b?.importName, "Foo")
    }

    func testMinimalSpaces() {
        let b = parse("import Foo//@mxcl~>1.0")
        XCTAssertEqual(b?.dependencyName, "mxcl/Foo")
        XCTAssertEqual(b?.constraint, .upToNextMajor(from: .one))
        XCTAssertEqual(b?.importName, "Foo")
    }

    func testCanOverrideImportName() {
        let b = parse("import Foo  // mxcl/Bar ~> 1.0")
        XCTAssertEqual(b?.dependencyName, "mxcl/Bar")
        XCTAssertEqual(b?.constraint, .upToNextMajor(from: .one))
        XCTAssertEqual(b?.importName, "Foo")
    }

    func testCanProvideFullURL() {
        let b = parse("import Foo  // https://example.com/mxcl/Bar.git ~> 1.0")
        XCTAssertEqual(b?.dependencyName, "https://example.com/mxcl/Bar.git")
        XCTAssertEqual(b?.constraint, .upToNextMajor(from: .one))
        XCTAssertEqual(b?.importName, "Foo")
    }

    func testCanDoSpecifiedImports() {
        let kinds = [
            "struct",
             "class",
             "enum",
             "protocol",
             "typealias",
             "func",
             "let",
             "var"
        ]
        for kind in kinds {
            let b = parse("import \(kind) Foo.bar  // https://example.com/mxcl/Bar.git ~> 1.0")
            XCTAssertEqual(b?.dependencyName, "https://example.com/mxcl/Bar.git")
            XCTAssertEqual(b?.constraint, .upToNextMajor(from: .one))
            XCTAssertEqual(b?.importName, "Foo")
        }
    }

    func testCanUseTestable() {
        let b = parse("@testable import Foo  // @bar ~> 1.0")
        XCTAssertEqual(b?.dependencyName, "bar/Foo")
        XCTAssertEqual(b?.constraint, .upToNextMajor(from: .one))
        XCTAssertEqual(b?.importName, "Foo")
    }
}

extension Constraint: Equatable {
    public static func ==(lhs: Constraint, rhs: Constraint) -> Bool {
        switch (lhs, rhs) {
        case (.upToNextMajor(let v1), .upToNextMajor(let v2)), (.exact(let v1), .exact(let v2)):
            return v1 == v2
        case let (.ref(ref1), .ref(ref2)):
            return ref1 == ref2
        default:
            return false
        }
    }
}

extension Version {
    static var one: Version {
        return Version(1,0,0)
    }
}
