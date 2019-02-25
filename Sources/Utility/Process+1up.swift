import Foundation
import Dispatch
import Path

public extension Process {
#if !os(Linux)
    func go() throws {
        if #available(OSX 10.13, *) {
            try run()
        } else {
            // throws an ObjC exception if it fails, we cannot catch that
            launch()
        }
    }
#elseif swift(>=5)
    func go() throws {
        try run()
    }
#else
    public func go() throws {
        guard let launchPath = launchPath.flatMap(Path.init) else {
            throw CocoaError.error(.fileReadNoSuchFile)
        }
        guard launchPath.isExecutable else {
            throw CocoaError.error(.fileReadNoPermission)
        }
        launch()  // fatals if the above is false
    }
#endif

    class Output: CustomStringConvertible {
        public let data: Data
        public lazy var string = { [unowned self] () -> String? in
            guard var str = String(data: self.data, encoding: .utf8) else { return nil }
            str = str.trimmingCharacters(in: .whitespacesAndNewlines)
            return str.isEmpty ? nil : str
        }()

        fileprivate init(_ data: Data) {
            self.data = data
        }

        public var description: String {
            return string ?? "<nil>"
        }
    }

    struct ExecutionError: LocalizedError {
        public let stdout: Output?
        public let stderr: Output?
        public let status: Int32
        public let arg0: String?
        public let args: [String]

        public var errorDescription: String? {
            var args: String {
                return self.args.map {
                    $0.replacingOccurrences(of: " ", with: "\\ ")
                }.joined(separator: " ")
            }
            var arg0: String {
                return self.arg0 ?? "<nil>"
            }
            var stdout: String? {
                return self.stdout?.string.map{ "out: `\($0)`" }
            }
            var stderr: String? {
                return self.stderr?.string.map{ "err: `\($0)`" }
            }
            let outs = [stdout, stderr].compactMap{ $0 }
            var rv = "\(status) <(\(arg0) \(args))"
            if !outs.isEmpty {
                rv += " -> " + outs.joined(separator: ", ")
            }
            return rv
        }
    }

    enum OutputType {
        case stdout
    }

    func runSync(_: OutputType) throws -> Output {
        let q = DispatchQueue(label: "output-queue")

        var out = Data()

        let outpipe = Pipe()
        standardOutput = outpipe

      #if !os(Linux)
        outpipe.fileHandleForReading.readabilityHandler = { handler in
            q.async {
                out.append(handler.availableData)
            }
        }
      #endif

        try go()
        waitUntilExit()

      #if os(Linux)
        out = outpipe.fileHandleForReading.readDataToEndOfFile()
      #endif

        func finish() throws -> Output {
            guard terminationStatus == 0, terminationReason == .exit else {
                throw ExecutionError(stdout: .init(out), stderr: nil, status: terminationStatus, arg0: launchPath, args: arguments ?? [])
            }
            return Output(out)
        }

      #if !os(Linux)
        outpipe.fileHandleForReading.readabilityHandler = nil

        return try q.sync(execute: finish)
      #else
        return try finish()
      #endif
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

        if tee, let str = String(data: err, encoding: .utf8) {
            //TODO should avoid doing the above twice and get this into the err-`Output` somehow
            fputs(str, stderr)
        }
    #endif

        func finish() throws -> (stdout: Output, stderr: Output) {
            guard terminationStatus == 0, terminationReason == .exit else {
                throw ExecutionError(stdout: .init(out), stderr: .init(err), status: terminationStatus, arg0: launchPath, args: arguments ?? [])
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

    func launchAndWaitForSuccessfulExit() throws {
        try go()
        waitUntilExit()

        guard terminationReason == .exit, terminationStatus == 0 else {
            throw ExecutionError(stdout: nil, stderr: nil, status: terminationStatus, arg0: launchPath, args: arguments ?? [])
        }
    }
}
