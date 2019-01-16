import protocol Foundation.LocalizedError

public protocol CommandLineError: LocalizedError {
    // typically you would not capitalize words in a stderr-error string
    // you may choose to implement errorDescription and capitalize that
    var stderrString: String { get }
}

public extension CommandLineError {
    public var errorDescription: String? {
        return stderrString
    }
}

#if os(Linux)
import func Glibc.strerror_r
import var Glibc.EINVAL
import var Glibc.ERANGE
#else
import func Darwin.strerror_r
import var Darwin.EINVAL
import var Darwin.ERANGE
#endif

func strerror(_ code: Int32) -> String {
    var cap = 64
    while cap <= 16 * 1024 {
        var buf = [Int8](repeating: 0, count: cap)
        let err = strerror_r(code, &buf, buf.count)
        if err == EINVAL {
            return "unknown error \(code)"
        }
        if err == ERANGE {
            cap *= 2
            continue
        }
        if err != 0 {
            return "fatal: strerror_r: \(err)"
        }
        return "\(String(cString: buf)) (\(code))"
    }
    return "fatal: strerror_r: ERANGE"
}
