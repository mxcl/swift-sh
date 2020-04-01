@testable import Command
import XCTest
import Path

class ModeUnitTests: XCTestCase {
    func testValidEjects() throws {
        func test(args: String..., line: UInt = #line, force: Bool, isTTY: Bool) throws {
            let mode = try Mode(for: ["arg0"] + args, isTTY: true)
            switch mode {
            case .eject(let path, let f):
                XCTAssertEqual(f, force, line: line)
                XCTAssertEqual(path, Path.cwd/"foo", line: line)
            default:
                XCTFail("\(mode) for \(args)", line: line)
            }
        }

        try test(args: "eject", "foo", force: false, isTTY: true)
        try test(args: "eject", "--force", "foo", force: true, isTTY: true)
        try test(args: "eject", "-f", "foo", force: true, isTTY: true)
        try test(args: "eject", "foo", "--force", force: true, isTTY: true)
        try test(args: "eject", "foo", "-f", force: true, isTTY: true)

        // even if we’re not connected to a TTY we try to eject
        // user needs to use `--` or `-` if they want to pass
        // these arguments to a stdin script
        try test(args: "eject", "foo", force: false, isTTY: false)
        try test(args: "eject", "--force", "foo", force: true, isTTY: false)
        try test(args: "eject", "-f", "foo", force: true, isTTY: false)
        try test(args: "eject", "foo", "--force", force: true, isTTY: false)
        try test(args: "eject", "foo", "-f", force: true, isTTY: false)
    }

    func testInvalidEjects() throws {
        func test(args: String...) throws {
            _ = try Mode(for: args, isTTY: true)
        }
        XCTAssertThrowsError(try test(args: "arg0", "--force", "eject", "foo"))
        XCTAssertThrowsError(try test(args: "arg0", "-f", "eject", "foo"))
        XCTAssertThrowsError(try test(args: "arg0", "--force", "eject"))
        XCTAssertThrowsError(try test(args: "arg0", "-f", "eject"))
        XCTAssertThrowsError(try test(args: "arg0", "eject"))
        XCTAssertThrowsError(try test(args: "arg0", "eject"))
    }

    func testValidRun() throws {
        try Path.mktemp { tmpdir in
            let foo = try DynamicPath(tmpdir).foo.touch()

            func test(args: String..., line: UInt = #line) throws {
                let mode = try Mode(for: ["arg0"] + args, isTTY: true)
                switch mode {
                case .run(.file(let path), let otherArgs):
                    XCTAssertEqual(path, foo, line: line)
                    XCTAssertEqual(otherArgs, args.dropFirst(), line: line)
                default:
                    XCTFail("\(mode) for \(args)", line: line)
                }
            }
            try test(args: foo.string)
            try test(args: foo.string, "--bar")
            try test(args: foo.string, "--bar", "flubbles")
        }
    }

    func testValidStdinRun() throws {
        func test(args: String..., line: UInt = #line) throws {
            let mode = try Mode(for: ["arg0"] + args, isTTY: false)
            switch mode {
            case .run(.stdin, let otherArgs):
                XCTAssertEqual(otherArgs, ArraySlice(args), line: line)
            default:
                XCTFail("\(mode) for \(args)", line: line)
            }
        }
        try test(args: "foo")
        try test(args: "foo", "--bar")
        try test(args: "foo", "--bar", "flubbles")
    }

    func testDash() throws {
        func test(args: String..., line: UInt = #line) throws {
            let mode = try Mode(for: ["arg0"] + args, isTTY: true)
            switch mode {
            case .run(.stdin, let otherArgs):
                XCTAssertEqual(otherArgs, args.dropFirst(), line: line)
            default:
                XCTFail("\(mode) for \(args)", line: line)
            }
        }
        try test(args: "-")
        try test(args: "-", "--bar")
        try test(args: "-", "eject", "foo")

        try test(args: "--")
        try test(args: "--", "--bar")
        try test(args: "--", "eject", "foo")
    }

    func testNoArgs() throws {
        XCTAssertThrowsError(try Mode(for: ["arg0"], isTTY: true))
        XCTAssertNoThrow(try Mode(for: ["arg0"], isTTY: false))
    }

    func testInvalidRun() throws {
        func test(args: String...) throws {
            _ = try Mode(for: ["arg0"] + args, isTTY: true)
        }
        XCTAssertNoThrow(try Mode(for: ["arg0", "--force", "foo"], isTTY: true))
        XCTAssertNoThrow(try Mode(for: ["arg0", "-f", "bar"], isTTY: true))

        // user-friendly refusal to allow invalid argument order
        XCTAssertThrowsError(try Mode(for: ["arg0", "--force", "eject"], isTTY: true))
        XCTAssertThrowsError(try Mode(for: ["arg0", "-f", "eject"], isTTY: true))

        // force is ok in general though
        XCTAssertNoThrow(try Mode(for: ["arg0", "--force", "foo"], isTTY: false))
        XCTAssertNoThrow(try Mode(for: ["arg0", "-f", "bar"], isTTY: false))
    }

    func testHelp() throws {
        func test1(args: String..., line: UInt = #line, isTTY: Bool) throws {
            let mode = try Mode(for: ["arg0"] + args, isTTY: isTTY)
            switch mode {
            case .help:
                break
            default:
                XCTFail("\(mode) for \(args)", line: line)
            }
        }

        try test1(args: "-h", isTTY: true)
        try test1(args: "--help", isTTY: true)
        try test1(args: "--help", "-h", isTTY: true)
//
//        func test2(args: String..., line: UInt = #line, isTTY: Bool) throws {
//            let mode = try Mode(for: ["arg0"] + args, isTTY: isTTY)
//            switch mode {
//            case .run(.stdin, let otherArgs):
//                XCTAssertEqual(ArraySlice(args), otherArgs, line: line)
//            default:
//                XCTFail("\(mode) for \(args)", line: line)
//            }
//        }
//
//        try test2(args: "--", "-h", isTTY: false)
//        try test2(args: "--", "-h", "--bar", isTTY: false)
//        try test2(args: "--", "--help", isTTY: false)
//        try test2(args: "--", "--help", "--bar", isTTY: false)
    }
}
