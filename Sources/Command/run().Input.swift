import Utility
import Path

#if !os(Linux)
import Darwin
#else
import Glibc
#endif

enum Input {
    case stdin
    case file(Path)
    case namedPipe(UnsafeMutablePointer<FILE>)

    var name: String {
        switch self {
        case .stdin:
            return "<stdin>"
        case .file(let path):
            return path.basename()
        case .namedPipe(let fp):
            return "<named-pipe-\(fileno(fp))>"
        }
    }
}

extension Path {
    var namedPipe: UnsafeMutablePointer<FILE>? {
        var sbuf = stat()
        guard let fp = fopen(string, "r") else {
            return nil
        }
    #if !os(Linux)
        guard fstat(Int32(fp.pointee._file), &sbuf) == 0 else {
            fclose(fp)
            return nil
        }
    #else
        guard fstat(fp.pointee._fileno, &sbuf) == 0 else {
            fclose(fp)
            return nil
        }
    #endif
        if sbuf.st_mode & S_IFMT == S_IFIFO {
            return fp
        } else {
            fclose(fp)
            return nil
        }
    }
}
