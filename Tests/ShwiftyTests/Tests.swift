@testable import Shwifty
import XCTest

class Tests: XCTestCase {
    func test1() {
        let a = parse("import Foo // @mxcl ~> 1.0")
        XCTAssertEqual(a?.0, "mxcl/Foo")
        XCTAssertEqual(a!.1, .upToNextMajor(from: .one))

        let b = parse("import    Foo       //     @mxcl    ~>      1.0")
        XCTAssertEqual(b?.0, "mxcl/Foo")
        XCTAssertEqual(b!.1, .upToNextMajor(from: .one))
    }

    func test2() {
        let a = parse("import Foo // @mxcl == 1.0")
        XCTAssertEqual(a?.0, "mxcl/Foo")
        XCTAssertEqual(a!.1, .exact(.one))
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
