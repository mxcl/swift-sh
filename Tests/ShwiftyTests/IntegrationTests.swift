@testable import Command
@testable import Library
import XCTest
import Path

class RunIntegrationTests: XCTestCase {
    override class func setUp() {
        guard Path.selfCache.isDirectory else { return }
        for entry in try! Path.selfCache.ls() where entry.kind == .directory && entry.path.basename().hasPrefix(scriptBaseName) {
            try! entry.path.delete()
        }
    }

    func testConventional() {
        XCTAssertEqual(.resultScriptOutput, exec: .resultScript)
    }

    func testNamingMismatch() {
        XCTAssertEqual("Promise(3)", exec: """
            import PMKFoundation  // PromiseKit/Foundation ~> 3
            import PromiseKit

            print(Promise.value(3))
            """)
    }

    func testTestableImport() {
        XCTAssertEqual(".success(4)", exec: """
            import Foundation
            @testable import Result  // @antitypical ~> 4.1

            print(Result<Int, CocoaError>.success(4))
            """)
    }

    func testTestableFullySpecifiedURL() {
        XCTAssertEqual(".success(5)", exec: """
            import Foundation
            @testable import Result  // https://github.com/antitypical/Result ~> 4.1

            print(Result<Int, CocoaError>.success(5))
            """)
    }

    func testTestableExactVersion() {
        XCTAssertEqual(".success(5)", exec: """
            import Foundation
            @testable import Result  // antitypical/Result == 4.1

            print(Result<Int, CocoaError>.success(5))
            """)
    }

    func testTestableExactRevision() {
        XCTAssertEqual(".success(5)", exec: """
            import Foundation
            @testable import Result  // antitypical/Result == 67613b45

            print(Result<Int, CocoaError>.success(5))
            """)
    }

    func testStandardInputCanBeUsedInScript() throws {
        let stdin = Pipe()
        let stdout = Pipe()
        let hello = "Hello\n".data(using: .utf8)!

        try write(script: "print(readLine()!)") { file in
            let task = Process(arg0: file)
            task.standardInput = stdin
            task.standardOutput = stdout

            task.launchPath = file.string
            try task.go()

            stdin.fileHandleForWriting.write(hello)
            task.waitUntilExit()

            XCTAssertEqual(task.terminationReason, .exit)
            XCTAssertEqual(task.terminationStatus, 0)

            let got = stdout.fileHandleForReading.readDataToEndOfFile()

            XCTAssertEqual(got, hello)
        }
    }

    func testStandardInputCanBeUsedBySwiftSh() throws {
        let stdin = Pipe()
        let stdout = Pipe()
        let task = Process(arg0: shebang)
        task.standardInput = stdin
        task.standardOutput = stdout
        try task.go()

        stdin.fileHandleForWriting.write("print(1)".data(using: .utf8)!)
        stdin.fileHandleForWriting.closeFile()
        task.waitUntilExit()

        XCTAssertEqual(task.terminationReason, .exit)
        XCTAssertEqual(task.terminationStatus, 0)
        XCTAssertEqual(stdout.fileHandleForReading.readDataToEndOfFile(), "1\n".data(using: .utf8))
    }

    func testArguments() {
        XCTAssertEqual(".success(3)", exec: """
            import Foundation
            @testable import Result  // https://github.com/antitypical/Result ~> 4.1

            let arg = CommandLine.arguments[1]
            print(Result<Int, CocoaError>.success(Int(arg)!))
            """, arg: "3")
    }

    func testNSHipsterExample() throws {
        let path = Path(#file)!.parent.parent.parent.Examples.cards
        let code = try StreamReader(path: path).dropFirst().joined(separator: "\n")
        XCTAssertRuns(exec: code)
    }

    func testRelativePath() throws {
        try write(script: "print(123)") { file in
            let task = Process(arg0: file)
            task.launchPath = "/bin/sh"
            task.arguments = ["-c", "./\(file.basename())"]
            task.currentDirectoryPath = file.parent.string
            let stdout = try task.runSync(tee: true).stdout.string?.chuzzled()
            XCTAssertEqual(stdout, "123")
        }
    }

    func testCWD() throws {
        let cwd = FileManager.default.currentDirectoryPath
        let script = """
            import Foundation
            print(FileManager.default.currentDirectoryPath)
            """
        XCTAssertEqual(cwd, exec: script)
    }
}

class EjectIntegrationTests: XCTestCase {
    func testForce() throws {

        func go(file: Path, insertionIndex: Int, flag: String) throws {
            var args = [file.string]
            args.insert(flag, at: insertionIndex)

            let task = Process(arg0: shebang)
            task.arguments = ["eject"] + args

            try Path.mktemp { tmpdir in
                task.currentDirectoryPath = tmpdir.string
                try task.go()
                task.waitUntilExit()

                XCTAssertEqual(task.terminationReason, .exit)
                XCTAssertEqual(task.terminationStatus, 0)

                let name = file.basename(dropExtension: true)
                let d = file.parent.join(name.capitalized)

                let memo = "flag: `\(flag)`, at: \(insertionIndex)"

                XCTAssertFalse(file.exists, memo)
                XCTAssert(d.isDirectory, memo)
                XCTAssert(d.join("Package.swift").isFile, memo)
                XCTAssert(d.join("Sources").isDirectory, memo)
                XCTAssert(d.join("Sources/main.swift").isFile, memo)

                let build = Process(arg0: Path.swift, arg1: "run")
                build.currentDirectoryPath = d.string
                let out = try build.runSync().stdout.string
                XCTAssertEqual(out, String.resultScriptOutput)
            }
        }

        for flag in ["-f", "--force"] {
            for insertionIndex in 0...1 {
                try write(script: .resultScript) { file in
                    try go(file: file, insertionIndex: insertionIndex, flag: flag)
                }
            }
        }
    }

    func testFilenameDirectoryClash() throws {
        // if the file is `foo` and we will create a package `Foo` in the same directory
        // this is a filename clash on macOS with its case insensitive filesystem
        // and we still should *work*
        //TODO should check the filesystem is insenstive to verify test is working

        try Path.mktemp { tmpdir -> Void in
            let file = tmpdir/"foo"
            try """
                #!/usr/bin/swift sh

                print(123)
                """.write(to: file)

            let task = Process()
            task.launchPath = shebang
            task.arguments = ["eject", file.string]
            try task.go()
            task.waitUntilExit()

            XCTAssertEqual(task.terminationReason, .exit)
            XCTAssertEqual(task.terminationStatus, 0)

            let d = tmpdir/"Foo"

            XCTAssertFalse(file.isFile)
            XCTAssert(d.isDirectory)
            XCTAssert(d.join("Package.swift").isFile)
            XCTAssert(d.join("Sources").isDirectory)
            XCTAssert(d.join("Sources/main.swift").isFile)
        }
    }

    func testRelativePath() throws {
        try Path.mktemp { tmpdir -> Void in
            let file = tmpdir/"foo"
            try "#!/usr/bin/swift sh".write(to: file)

            let task = Process()
            task.launchPath = shebang
            task.arguments = ["eject", file.basename()]
            task.currentDirectoryPath = tmpdir.string
            try task.go()
            task.waitUntilExit()

            XCTAssertEqual(task.terminationReason, .exit)
            XCTAssertEqual(task.terminationStatus, 0)

            let d = tmpdir/"Foo"

            XCTAssertFalse(file.isFile)
            XCTAssert(d.isDirectory)
            XCTAssert(d.join("Package.swift").isFile)
            XCTAssert(d.join("Sources").isDirectory)
            XCTAssert(d.join("Sources/main.swift").isFile)
        }
    }


    func testFailsIfNotScript() throws {
        try Path.mktemp { tmpdir -> Void in
            let file = tmpdir/"foo"
            try "foo".write(to: file)
            let pipe = Pipe()
            let task = Process()
            task.launchPath = shebang
            task.arguments = ["eject", file.string]
            task.standardError = pipe
            try task.go()
            task.waitUntilExit()

            let stderr = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.chuzzled()

            XCTAssertEqual(task.terminationReason, .exit)
            XCTAssertEqual(task.terminationStatus, 2)
            XCTAssertEqual(stderr, "error: " + EjectError.notScript.errorDescription!)
        }
    }
}

class TestingTheTests: XCTestCase {
    func testSwiftVersionIsWhatTestsExpect() {
        #if swift(>=5)
        let expected = "5"
        #elseif swift(>=4.2)
        let expected = "4.2"
        #else
        fatalError()
        #endif
        XCTAssertEqual(expected, exec: """
            #if swift(>=5)
            print(5)
            #elseif swift(>=4.2)
            print(4.2)
            #else
            fatalError()
            #endif
            """)
    }
}

private func write(script: String, line: UInt = #line, body: (Path) throws -> Void) throws {
    try Path.mktemp { tmpdir -> Void in
        let file = tmpdir.join("\(scriptBaseName)-\(line).swift")
        try "#!\(shebang)\n\(script)".write(to: file)
        try file.chmod(0o0500)
        try body(file)
    }
}

private func XCTAssertRuns(exec: String, line: UInt = #line) {
    do {
        try write(script: exec, line: line) { file in
            let task = Process(arg0: file)
            try task.go()
            task.waitUntilExit()

            XCTAssertEqual(task.terminationReason, .exit, line: line)
            XCTAssertEqual(task.terminationStatus, 0, line: line)
        }
    } catch {
        XCTFail("\(error)", line: line)
    }
}

private extension Process {
    convenience init(arg0: Path, arg1: String? = nil) {
        self.init(arg0: arg0.string, arg1: arg1)
    }

    convenience init(arg0: String, arg1: String? = nil) {
        self.init()
        launchPath = arg0
        arguments = arg1.map{ [$0] } ?? []

    #if os(macOS) && Xcode
        // we need to ensure we are testing *this* toolchain
        //FIXME can be overridden at Xcode Menu level and we won’t see that
        let path = Path.root.join(CommandLine.arguments[0]).parent.parent.parent.parent.parent.parent.parent.parent.parent
        var env = ProcessInfo.processInfo.environment
        env["DEVELOPER_DIR"] = path.string
        environment = env
    #endif
    }
}

private func XCTAssertEqual(_ expected: String, exec: String, arg: String? = nil, line: UInt = #line) {
    do {
        try write(script: exec, line: line) { file in
            let task = Process(arg0: file, arg1: arg)
            let stdout = try task.runSync(tee: true).stdout.string?.chuzzled()
            XCTAssertEqual(stdout, expected, line: line)
        }
    } catch {
        XCTFail("\(error)", line: line)
    }
}

private var shebang: String {
#if Xcode
    return Bundle(for: RunIntegrationTests.self).path.parent.join("Executable").string
#elseif os(Linux)
    // Bundle(for:) is unimplemented
    return Path.root.join(#file).parent.parent.parent.join(".build/debug/swift-sh").string
#else
    return Bundle(for: RunIntegrationTests.self).path.parent.join("swift-sh").string
#endif
}

private extension String {
    static var resultScript: String {
        return """
        import Foundation
        import Result  // @antitypical ~> 4.1

        print(Result<Int, CocoaError>.success(3))
        """
    }

    static var resultScriptOutput: String {
        return ".success(3)"
    }
}

private let scriptBaseName = "dev.mxcl.swift-sh-tests"
