//MARK: Collection helpers

public extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}


//MARK: strerror

#if os(Linux)
import func Glibc.strerror_r
import var Glibc.EINVAL
import var Glibc.ERANGE
#else
import func Darwin.strerror_r
import var Darwin.EINVAL
import var Darwin.ERANGE
#endif

public func strerror(_ code: Int32) -> String {
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


//MARK: Regular Expression helpers

import struct Foundation.NSRange
import class Foundation.NSTextCheckingResult
import class Foundation.NSRegularExpression
import var Foundation.NSNotFound

public extension NSRegularExpression {
    func firstMatch(in str: String) -> NSTextCheckingResult? {
        let range = NSRange(location: 0, length: str.utf16.count)
        return firstMatch(in: str, range: range)
    }
}

public extension NSTextCheckingResult {
    func isMatch(at: Int) -> Bool {
        guard at < numberOfRanges else { return false }
        return range(at: at).location != NSNotFound
    }
}

public extension String {
    subscript(range: NSRange) -> Substring {
        return self[Range(range, in: self)!]
    }
}


//MARK: Path.which

import class Foundation.ProcessInfo
import Path

public extension Path {
    static func which(_ cmd: String) -> Path? {
        for prefix in PATH {
            let path = prefix/cmd
            if path.isExecutable {
                return path
            }
        }
        return nil
    }
}

private var PATH: [Path] {
    guard let PATH = ProcessInfo.processInfo.environment["PATH"] else {
        return []
    }
    return PATH.split(separator: ":").map {
        if $0.first == "/" {
            return Path.root/$0
        } else {
            return Path.cwd/$0
        }
    }
}
