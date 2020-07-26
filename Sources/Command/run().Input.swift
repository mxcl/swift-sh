import class Foundation.FileHandle
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
    case namedPipe(FileHandle)

    var name: String {
        switch self {
        case .stdin:
            return "StandardInput"
        case .file(let path):
            return path.basename()
        case .namedPipe(let fh):
            return "NamedPipe_\(fh.fileDescriptor))"
        }
    }
}

extension Path {
    var namedPipe: FileHandle? {
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
        #if !os(Linux)
            return FileHandle(fileDescriptor: fileno(fp))
        #else
            return FileHandle(fileDescriptor: fp.pointee._fileno)
        #endif
        } else {
            fclose(fp)
            return nil
        }
    }
}
