import Foundation
import Path

public func exec(arg0: String, args: [String]) throws -> Never {
    let args = CStringArray([arg0] + args)

    guard execv(arg0, args.cArray) != -1 else {
        throw POSIXError.execv(executable: arg0, errno: errno)
    }

    fatalError("Impossible if execv succeeded")
}

public enum POSIXError: LocalizedError {
    case execv(executable: String, errno: Int32)

    public var errorDescription: String? {
        switch self {
        case .execv(let executablePath, let errno):
            return "execv failed: \(Utility.strerror(errno)): \(executablePath)"
        }
    }
}

private final class CStringArray {
    /// The null-terminated array of C string pointers.
    public let cArray: [UnsafeMutablePointer<Int8>?]

    /// Creates an instance from an array of strings.
    public init(_ array: [String]) {
        cArray = array.map({ $0.withCString({ strdup($0) }) }) + [nil]
    }

    deinit {
        for case let element? in cArray {
            free(element)
        }
    }
}
