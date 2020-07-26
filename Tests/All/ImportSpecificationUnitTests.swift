@testable import Script
import Version
import XCTest
import Path

class ImportSpecificationUnitTests: XCTestCase {
    func testWigglyArrow() throws {
        let a = try parse("import Foo // @mxcl ~> 1.0", from: .path(Path.cwd.join("script.swift")))
        XCTAssertEqual(a?.dependencyName, .github(user: "mxcl", repo: "Foo"))
        XCTAssertEqual(a?.constraint, .upToNextMajor(from: .one))
        XCTAssertEqual(a?.importName, "Foo")
    }

    func testTrailingWhitespace() throws {
        let a = try parse("import Foo // @mxcl ~> 1.0 ", from: .path(Path.cwd.join("script.swift")))
        XCTAssertEqual(a?.dependencyName, .github(user: "mxcl", repo: "Foo"))
        XCTAssertEqual(a?.constraint, .upToNextMajor(from: .one))
        XCTAssertEqual(a?.importName, "Foo")
    }

    func testExact() throws {
        let a = try parse("import Foo // @mxcl == 1.0", from: .path(Path.cwd.join("script.swift")))
        XCTAssertEqual(a?.dependencyName, .github(user: "mxcl", repo: "Foo"))
        XCTAssertEqual(a?.constraint, .exact(.one))
        XCTAssertEqual(a?.importName, "Foo")
    }

    func testMoreSpaces() throws {
        let b = try parse("import    Foo       //     @mxcl    ~>      1.0", from: .path(Path.cwd.join("script.swift")))
        XCTAssertEqual(b?.dependencyName, .github(user: "mxcl", repo: "Foo"))
        XCTAssertEqual(b?.constraint, .upToNextMajor(from: .one))
        XCTAssertEqual(b?.importName, "Foo")
    }

    func testMinimalSpaces() throws {
        let b = try parse("import Foo//@mxcl~>1.0", from: .path(Path.cwd.join("script.swift")))
        XCTAssertEqual(b?.dependencyName, .github(user: "mxcl", repo: "Foo"))
        XCTAssertEqual(b?.constraint, .upToNextMajor(from: .one))
        XCTAssertEqual(b?.importName, "Foo")
    }

    func testCanOverrideImportName() throws {
        let b = try parse("import Foo  // mxcl/Bar ~> 1.0", from: .path(Path.cwd.join("script.swift")))
        XCTAssertEqual(b?.dependencyName, .github(user: "mxcl", repo: "Bar"))
        XCTAssertEqual(b?.constraint, .upToNextMajor(from: .one))
        XCTAssertEqual(b?.importName, "Foo")
    }

    func testCanOverrideImportNameUsingNameWithHyphen() throws {
        let b = try parse("import Bar  // mxcl/swift-bar ~> 1.0", from: .path(Path.cwd.join("script.swift")))
        XCTAssertEqual(b?.dependencyName, .github(user: "mxcl", repo: "swift-bar"))
        XCTAssertEqual(b?.constraint, .upToNextMajor(from: .one))
        XCTAssertEqual(b?.importName, "Bar")
    }

    func testCanProvideLocalPath() throws {
        let homePath = Path.home
        let b = try parse("import Bar  // \(homePath.string)", from: .path(homePath.join("script.swift")))
        XCTAssertEqual(b?.dependencyName, .local(Path(homePath)))
        XCTAssertEqual(b?.importName, "Bar")
        XCTAssertEqual(b?.packageLine, ".package(path: \"\(homePath.string)\")")
    }

    func testCanProvideLocalPathWithTilde() throws {
        let homePath = Path.home
        let b = try parse("import Bar  // ~/", from: .path(homePath.join("script.swift")))
        XCTAssertEqual(b?.dependencyName, .local(Path(homePath)))
        XCTAssertEqual(b?.importName, "Bar")
        XCTAssertEqual(b?.packageLine, ".package(path: \"\(homePath.string)\")")
    }

    func testCanProvideLocalRelativeCurrentPath() throws {
        let cwd = Path.cwd
        let b = try parse("import Bar  // ./", from: .path(cwd.join("script.swift")))
        XCTAssertEqual(b?.dependencyName, .local(Path(cwd)))
        XCTAssertEqual(b?.importName, "Bar")
        XCTAssertEqual(b?.packageLine, ".package(path: \"\(cwd.string)\")")
    }

    func testCanProvideLocalRelativeNonCurrentPath() throws {
        let homePath = Path.home
        // Provide a script path that's inside the home directory (not cwd)
        let b = try parse("import Bar  // ./", from: .path(homePath.join("script.swift")))
        XCTAssertEqual(b?.dependencyName, .local(Path(homePath)))
        XCTAssertEqual(b?.importName, "Bar")
        XCTAssertEqual(b?.packageLine, ".package(path: \"\(homePath.string)\")")
    }

    func testCanProvideLocalRelativeParentPath() throws {
        let cwdParent = Path.cwd/"../"
        let b = try parse("import Bar  // ../", from: .path(Path.cwd.join("script.swift")))
        XCTAssertEqual(b?.dependencyName, .local(cwdParent))
        XCTAssertEqual(b?.importName, "Bar")
        XCTAssertEqual(b?.packageLine, ".package(path: \"\(cwdParent.string)\")")
    }

    func testCanProvideLocalRelativeTwoParentsUpPath() throws {
        let cwdParent = Path.cwd/"../../"
        let b = try parse("import Bar  // ../../", from: .path(Path.cwd.join("script.swift")))
        XCTAssertEqual(b?.dependencyName, .local(cwdParent))
        XCTAssertEqual(b?.importName, "Bar")
        XCTAssertEqual(b?.packageLine, ".package(path: \"\(cwdParent.string)\")")
    }

    func testCanProvideFullURL() throws {
        let b = try parse("import Foo  // https://example.com/mxcl/Bar.git ~> 1.0", from: .path(Path.cwd.join("script.swift")))
        XCTAssertEqual(b?.dependencyName, .url(URL(string: "https://example.com/mxcl/Bar.git")!))
        XCTAssertEqual(b?.constraint, .upToNextMajor(from: .one))
        XCTAssertEqual(b?.importName, "Foo")
    }

    func testCanProvideFullURLWithHyphen() throws {
        let b = try parse("import Bar  // https://example.com/mxcl/swift-bar.git ~> 1.0", from: .path(Path.cwd.join("script.swift")))
        XCTAssertEqual(b?.dependencyName, .url(URL(string: "https://example.com/mxcl/swift-bar.git")!))
        XCTAssertEqual(b?.constraint, .upToNextMajor(from: .one))
        XCTAssertEqual(b?.importName, "Bar")
    }

    func testCanProvideFullSSHURLWithHyphen() throws {
        let url = "ssh://git@github.com/MariusCiocanel/swift-sh.git"
        let b = try parse("import Bar  // \(url) ~> 1.0", from: .path(Path.cwd.join("script.swift")))
        XCTAssertEqual(b?.dependencyName, .url(URL(string: url)!))
        XCTAssertEqual(b?.constraint, .upToNextMajor(from: .one))
        XCTAssertEqual(b?.importName, "Bar")
        XCTAssertEqual(b?.dependencyName.urlString, url)
    }

    func testCanProvideCommonSSHURLStyleWithHyphen() throws {
        let uri = "git@github.com:MariusCiocanel/swift-sh.git"
        let b = try parse("import Bar  // \(uri) ~> 1.0", from: .path(Path.cwd.join("script.swift")))
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
            let b = try parse("import \(kind) Foo.bar  // https://example.com/mxcl/Bar.git ~> 1.0", from: .path(Path.cwd.join("script.swift")))
            XCTAssertEqual(b?.dependencyName, .url(URL(string: "https://example.com/mxcl/Bar.git")!))
            XCTAssertEqual(b?.constraint, .upToNextMajor(from: .one))
            XCTAssertEqual(b?.importName, "Foo")
        }
    }

    func testCanUseTestable() throws {
        let b = try parse("@testable import Foo  // @bar ~> 1.0", from: .path(Path.cwd.join("script.swift")))
        XCTAssertEqual(b?.dependencyName, .github(user: "bar", repo: "Foo"))
        XCTAssertEqual(b?.constraint, .upToNextMajor(from: .one))
        XCTAssertEqual(b?.importName, "Foo")
    }

    func testLatestVersion() throws {
        let b = try parse("import Foo  // @bar", from: .path(Path.cwd.join("script.swift")))
        XCTAssertEqual(b?.dependencyName, .github(user: "bar", repo: "Foo"))
        XCTAssertEqual(b?.constraint, .latest)
        XCTAssertEqual(b?.importName, "Foo")
    }

    func testSwiftVersion() {
    #if swift(>=5) || compiler(>=5.0)
    #if compiler(>=5.3)
        let expected = "5.3"
    #elseif compiler(>=5.2)
        let expected = "5.2"
    #elseif compiler(>=5.1)
        let expected = "5.1"
    #else
        let expected = "5.0"
    #endif
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
