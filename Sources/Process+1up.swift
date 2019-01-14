import Foundation
import Dispatch

public extension Process {
#if os(Linux)
    public func go() throws {
        guard Path.root.join(launchPath!).isExecutable else { throw FileNotFoundError(launchPath: launchPath!) }
        launch()  // `run` is not available for some reason
    }
#else
    public func go() throws {
        if #available(OSX 10.13, *) {
            try run()
        } else {
            // throws an ObjC exception if it fails, we cannot catch that
            launch()
        }
    }
#endif

    class Output {
        public let data: Data
        public lazy var string = { [unowned self] () -> String? in
            guard var str = String(data: self.data, encoding: .utf8) else { return nil }
            str = str.trimmingCharacters(in: .whitespacesAndNewlines)
            return str.isEmpty ? nil : str
            }()

        fileprivate init(_ data: Data) {
            self.data = data
        }
    }

#if os(Linux)
    public struct FileNotFoundError: LocalizedError {
        public let launchPath: String
        public var errorDescription: String? {
            return "executable file not found: \(launchPath)"
        }
    }
#endif
    
    struct ExecutionError: Error {
        public let stdout: Output
        public let stderr: Output
        public let status: Int32
        public let arg0: String
        public let args: [String]
    }

    func runSync(tee: Bool = false) throws -> (stdout: Output, stderr: Output) {
        let q = DispatchQueue(label: "output-queue")

        var out = Data()
        var err = Data()

        let outpipe = Pipe()
        standardOutput = outpipe

        let errpipe = Pipe()
        standardError = errpipe

    #if !os(Linux)
        outpipe.fileHandleForReading.readabilityHandler = { handler in
            q.async {
                out.append(handler.availableData)
            }
        }

        errpipe.fileHandleForReading.readabilityHandler = { handler in
            q.async {
                let data = handler.availableData
                err.append(data)
                if tee, let str = String(data: data, encoding: .utf8) {
                    Darwin.fputs(str, stderr)
                }
            }
        }
    #endif

        try go()
        waitUntilExit()

    #if os(Linux)
        out = outpipe.fileHandleForReading.readDataToEndOfFile()
        err = errpipe.fileHandleForReading.readDataToEndOfFile()
    #endif

        func finish() throws -> (stdout: Output, stderr: Output) {
            guard terminationStatus == 0, terminationReason == .exit else {
                throw ExecutionError(stdout: .init(out), stderr: .init(err), status: terminationStatus, arg0: launchPath!, args: arguments ?? [])
            }
            return (stdout: Output(out), stderr: Output(err))
        }

    #if !os(Linux)
        outpipe.fileHandleForReading.readabilityHandler = nil
        errpipe.fileHandleForReading.readabilityHandler = nil

        return try q.sync(execute: finish)
    #else
        return try finish()
    #endif
    }

    static func system(_ arg0: String, _ args: String..., cwd: Path? = nil) throws {
        let task = Process()
        task.launchPath = arg0
        task.arguments = args
        if let cwd = cwd?.string {
            task.currentDirectoryPath = cwd
        }
        try task.go()
        task.waitUntilExit()

        guard task.terminationReason == .exit, task.terminationStatus == 0 else {
            let output = Output(Data())
            throw ExecutionError(stdout: output, stderr: output, status: task.terminationStatus, arg0: arg0, args: args)
        }
    }
}
