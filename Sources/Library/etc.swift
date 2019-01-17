import protocol Foundation.LocalizedError

public extension CommandLine {
    static let usage = """
        swift sh PATH
        swift sh eject PATH [-f|--force]
        """

    enum Error: LocalizedError {
        case invalidUsage

        public var errorDescription: String? {
            switch self {
            case .invalidUsage:
                return CommandLine.usage
            }
        }
    }
}

public extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
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
