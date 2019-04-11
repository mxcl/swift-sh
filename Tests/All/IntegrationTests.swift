@testable import Command
@testable import Script
import Utility
import XCTest
import Path

class RunIntegrationTests: XCTestCase {
    override class func setUp() {
        guard Path.build.isDirectory else { return }
        for entry in try! Path.build.ls() where entry.kind == .directory && entry.path.basename().hasPrefix(scriptBaseName) {
            try! entry.path.delete()
        }
    }

    override func tearDown() {
    #if swift(>=5)
    #else
        // sleep or race condition bug in SwiftPM 4.2 causes
        // changes to be ignored if the same script name
        // is executed twice in quick succession.
        usleep(500_000)
    #endif
    }

    func testConventional() {
        XCTAssertEqual(.resultScriptOutput, exec: .resultScript)
    }

    func testNamingMismatch() {
        XCTAssertEqual("/", exec: """
            import Path  // mxcl/Path.swift ~> 0.15

            print(Path.root)
            """)
    }

    func testTestableImport() {
        XCTAssertEqual("1.2.3", exec: """
            import Foundation
            @testable import Version  // @mxcl ~> 1.0

            print(Version(1,2,3))
            """)
    }

    func testTestableFullySpecifiedURL() {
        XCTAssertEqual("2.3.4", exec: """
            import Foundation
            @testable import Version  // https://github.com/mxcl/Version ~> 1.0

            print(Version(2,3,4))
            """)
    }

    func testTestableExactVersion() {
        XCTAssertEqual("3.4.5", exec: """
            import Foundation
            @testable import Version  // mxcl/Version == 1.0.2

            print(Version(3,4,5))
            """)
    }

    func testTestableExactRevision() {
        XCTAssertEqual(".success(5)", exec: """
            import Foundation
            @testable import Result  // antitypical/Result == 67613b45

            print(Result<Int, CocoaError>.success(5))
            """)
    }

    func testTestableLatest() {
        XCTAssertEqual("7.8.9", exec: """
            import Version  // @mxcl

            print(Version(7,8,9))
            """)
    }

    func testUseLocalDependencyWithAbsolutePath() throws {
        let tmpdir = try Path.cwd.join("local_dep").mkdir()
        defer {_ = try? FileManager.default.removeItem(at: tmpdir.url)}

        let task = Process(arg0: "/bin/bash")
        task.currentDirectoryPath = tmpdir.string
        task.arguments = ["-c", "swift package init"]
        let stdout = Pipe()
        task.standardOutput = stdout
        try task.go()
        task.waitUntilExit()

        XCTAssertRuns(exec: """
            import local_dep  // \(tmpdir.string)
            """)
    }

    func testUseLocalDependencyWithRelativePath() throws {
        let depName = "local_dep"
        let tmpdir = try Path.cwd.join(depName).mkdir()
        defer {_ = try? FileManager.default.removeItem(at: tmpdir.url)}

        let task = Process(arg0: "/bin/bash")
        task.currentDirectoryPath = tmpdir.string
        task.arguments = ["-c", "swift package init"]
        let stdout = Pipe()
        task.standardOutput = stdout
        try task.go()
        task.waitUntilExit()

        XCTAssertRuns(exec: """
            import local_dep  // ./\(depName)
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

        stdin.fileHandleForWriting.write("print(\"\(#function)\")".data(using: .utf8)!)
        stdin.fileHandleForWriting.closeFile()
        task.waitUntilExit()

        XCTAssertEqual(task.terminationReason, .exit)
        XCTAssertEqual(task.terminationStatus, 0)

        let out = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        XCTAssertEqual(out, "\(#function)\n")
    }

    func testStandardInputCanBeUsedBySwiftShWithArgument() throws {
        let stdin = Pipe()
        let stdout = Pipe()
        let task = Process(arg0: shebang)
        task.arguments = ["foobar"]
        task.standardInput = stdin
        task.standardOutput = stdout
        try task.go()

        stdin.fileHandleForWriting.write("print(CommandLine.arguments[1])".data(using: .utf8)!)
        stdin.fileHandleForWriting.closeFile()
        task.waitUntilExit()

        XCTAssertEqual(task.terminationReason, .exit)
        XCTAssertEqual(task.terminationStatus, 0)

        let out = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        XCTAssertEqual(out, "foobar\n")
    }

    func testProcessSubstitution() throws {
        try write(script: "print(\"\(#function)\")") { script in
            let task = Process(arg0: "/bin/bash")
            task.arguments = [
                "-c", "\(shebang) <(cat \"\(script)\")"
            ]
            let stdout = try task.runSync(.stdout).string
            XCTAssertEqual(stdout, #function)
        }
    }

    func testProcessSubstitutionWithArgument() throws {
        try write(script: "print(CommandLine.arguments[1])") { script in
            let task = Process(arg0: "/bin/bash")
            task.arguments = [
                "-c", "\(shebang) <(cat \"\(script)\") \"\(#function)\""
            ]
            let stdout = try task.runSync(.stdout).string
            XCTAssertEqual(stdout, #function)
        }
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
            let stdout = try task.runSync(.stdout).string?.chuzzled()
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

    func testStdinScriptChangesAreSeen() throws {
        func go(input: String, line: UInt = #line) throws -> String? {
            let stdin = Pipe()
            let stdout = Pipe()
            let task = Process(arg0: shebang)
            task.standardInput = stdin
            task.standardOutput = stdout
            try task.go()

            stdin.fileHandleForWriting.write(input.data(using: .utf8)!)
            stdin.fileHandleForWriting.closeFile()
            task.waitUntilExit()

            XCTAssertEqual(task.terminationReason, .exit, line: line)
            XCTAssertEqual(task.terminationStatus, 0, line: line)

            XCTAssertEqual(try String(contentsOf: Path.build/"<stdin>/main.swift"), input, line: line)

            return String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        }
        for x in 1...3 {
            XCTAssertEqual(try go(input: "print(\(x))"), "\(x)\n")

        #if swift(>=5)
        #else
            // sleep or race condition bug in SwiftPM 4.2 causes these tests to fail
            sleep(1)
        #endif
        }
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
                let out = try build.runSync(.stdout).string
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

    func testWorksIfSymlinkBecomesBroken() {
        // creates two scripts for the same cache location
        // thus when the first is complete the `main.swift` symlink becomes broken
        // this is a regression test

        XCTAssertRuns(exec: "print(1)", line: 100)
        XCTAssertRuns(exec: "print(2)", line: 100)
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
        let expected = swiftVersion
        XCTAssertEqual(expected, exec: """
            #if swift(>=5)
                print(5.0)
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
    #else
        func swiftPath() throws -> String {
            let yaml = Path.root.join(#file).parent.parent.parent.join(".build/debug.yaml")
            for line in try StreamReader(path: yaml) {
                guard let line = line.chuzzled() else { continue }
                if line.hasPrefix("executable:"), line.hasSuffix("swiftc\"") {
                    let parts = line.split(separator: ":")
                    guard parts.count == 2 else { continue }
                    return Path.root.join(parts[1].trimmingCharacters(in: .init(charactersIn: " \n\""))).parent.string
                }
            }
            return "/usr/bin"
        }
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "\(try! swiftPath()):\(ProcessInfo.processInfo.environment["PATH"]!)"
        environment = env
    #endif
    }
}

private func XCTAssertEqual(_ expected: String, exec: String, arg: String? = nil, line: UInt = #line) {
    do {
        try write(script: exec, line: line) { file in
            let task = Process(arg0: file, arg1: arg)
            let stdout = try task.runSync(.stdout).string?.chuzzled()
            XCTAssertEqual(stdout, expected, line: line)
        }
    } catch {
        XCTFail("\(error)", line: line)
    }
}

private var shebang: String {
#if Xcode
    return Bundle(for: RunIntegrationTests.self).path.parent.join("swift-sh").string
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
