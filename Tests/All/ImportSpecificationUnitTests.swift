@testable import Script
import Version
import XCTest
import Path

class ImportSpecificationUnitTests: XCTestCase {
    func testWigglyArrow() throws {
        let a = try parse("import Foo // @mxcl ~> 1.0")
        XCTAssertEqual(a?.dependencyName, .github(user: "mxcl", repo: "Foo"))
        XCTAssertEqual(a?.constraint, .upToNextMajor(from: .one))
        XCTAssertEqual(a?.importName, "Foo")
    }

    func testTrailingWhitespace() throws {
        let a = try parse("import Foo // @mxcl ~> 1.0 ")
        XCTAssertEqual(a?.dependencyName, .github(user: "mxcl", repo: "Foo"))
        XCTAssertEqual(a?.constraint, .upToNextMajor(from: .one))
        XCTAssertEqual(a?.importName, "Foo")
    }

    func testExact() throws {
        let a = try parse("import Foo // @mxcl == 1.0")
        XCTAssertEqual(a?.dependencyName, .github(user: "mxcl", repo: "Foo"))
        XCTAssertEqual(a?.constraint, .exact(.one))
        XCTAssertEqual(a?.importName, "Foo")
    }

    func testMoreSpaces() throws {
        let b = try parse("import    Foo       //     @mxcl    ~>      1.0")
        XCTAssertEqual(b?.dependencyName, .github(user: "mxcl", repo: "Foo"))
        XCTAssertEqual(b?.constraint, .upToNextMajor(from: .one))
        XCTAssertEqual(b?.importName, "Foo")
    }

    func testMinimalSpaces() throws {
        let b = try parse("import Foo//@mxcl~>1.0")
        XCTAssertEqual(b?.dependencyName, .github(user: "mxcl", repo: "Foo"))
        XCTAssertEqual(b?.constraint, .upToNextMajor(from: .one))
        XCTAssertEqual(b?.importName, "Foo")
    }

    func testCanOverrideImportName() throws {
        let b = try parse("import Foo  // mxcl/Bar ~> 1.0")
        XCTAssertEqual(b?.dependencyName, .github(user: "mxcl", repo: "Bar"))
        XCTAssertEqual(b?.constraint, .upToNextMajor(from: .one))
        XCTAssertEqual(b?.importName, "Foo")
    }
    
    func testCanOverrideImportNameUsingNameWithHyphen() throws {
        let b = try parse("import Bar  // mxcl/swift-bar ~> 1.0")
        XCTAssertEqual(b?.dependencyName, .github(user: "mxcl", repo: "swift-bar"))
        XCTAssertEqual(b?.constraint, .upToNextMajor(from: .one))
        XCTAssertEqual(b?.importName, "Bar")
    }

    func testCanProvideLocalPath() throws {
        let homePath = Path.home
        let b = try parse("import Bar  // \(homePath.string)")
        XCTAssertEqual(b?.dependencyName, .local(homePath))
        XCTAssertEqual(b?.importName, "Bar")
        XCTAssertEqual(b?.packageLine, ".package(path: \"\(homePath.string)\"")
    }

    func testCanProvideLocalPathWithTilde() throws {
        let homePath = Path.home
        let b = try parse("import Bar  // ~/")
        XCTAssertEqual(b?.dependencyName, .local(homePath))
        XCTAssertEqual(b?.importName, "Bar")
        XCTAssertEqual(b?.packageLine, ".package(path: \"\(homePath.string)\"")
    }

    func testCanProvideFullURL() throws {
        let b = try parse("import Foo  // https://example.com/mxcl/Bar.git ~> 1.0")
        XCTAssertEqual(b?.dependencyName, .url(URL(string: "https://example.com/mxcl/Bar.git")!))
        XCTAssertEqual(b?.constraint, .upToNextMajor(from: .one))
        XCTAssertEqual(b?.importName, "Foo")
    }

    func testCanProvideFullURLWithHyphen() throws {
        let b = try parse("import Bar  // https://example.com/mxcl/swift-bar.git ~> 1.0")
        XCTAssertEqual(b?.dependencyName, .url(URL(string: "https://example.com/mxcl/swift-bar.git")!))
        XCTAssertEqual(b?.constraint, .upToNextMajor(from: .one))
        XCTAssertEqual(b?.importName, "Bar")
    }

    func testCanProvideFullSSHURLWithHyphen() throws {
        let url = "ssh://git@github.com/MariusCiocanel/swift-sh.git"
        let b = try parse("import Bar  // \(url) ~> 1.0")
        XCTAssertEqual(b?.dependencyName, .url(URL(string: url)!))
        XCTAssertEqual(b?.constraint, .upToNextMajor(from: .one))
        XCTAssertEqual(b?.importName, "Bar")
        XCTAssertEqual(b?.dependencyName.urlString, url)
    }

    func testCanProvideCommonSSHURLStyleWithHyphen() throws {
        let uri = "git@github.com:MariusCiocanel/swift-sh.git"
        let b = try parse("import Bar  // \(uri) ~> 1.0")
        XCTAssertEqual(b?.dependencyName, .scp(uri))
        XCTAssertEqual(b?.constraint, .upToNextMajor(from: .one))
        XCTAssertEqual(b?.importName, "Bar")
        XCTAssertEqual(b?.dependencyName.urlString, "git@github.com:MariusCiocanel/swift-sh.git")
    }

    func testCanDoSpecifiedImports() throws {
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
            let b = try parse("import \(kind) Foo.bar  // https://example.com/mxcl/Bar.git ~> 1.0")
            XCTAssertEqual(b?.dependencyName, .url(URL(string: "https://example.com/mxcl/Bar.git")!))
            XCTAssertEqual(b?.constraint, .upToNextMajor(from: .one))
            XCTAssertEqual(b?.importName, "Foo")
        }
    }

    func testCanUseTestable() throws {
        let b = try parse("@testable import Foo  // @bar ~> 1.0")
        XCTAssertEqual(b?.dependencyName, .github(user: "bar", repo: "Foo"))
        XCTAssertEqual(b?.constraint, .upToNextMajor(from: .one))
        XCTAssertEqual(b?.importName, "Foo")
    }

    func testLatestVersion() throws {
        let b = try parse("import Foo  // @bar")
        XCTAssertEqual(b?.dependencyName, .github(user: "bar", repo: "Foo"))
        XCTAssertEqual(b?.constraint, .latest)
        XCTAssertEqual(b?.importName, "Foo")
    }

    func testSwiftVersion() {
    #if swift(>=5) || compiler(>=5.0)
        let expected = "5.0"
    #else
        let expected = "4.2"
    #endif
        XCTAssertEqual(swiftVersion, expected)
    }
}

extension Version {
    static var one: Version {
        return Version(1,0,0)
    }
}
