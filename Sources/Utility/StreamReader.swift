import Foundation
import Path

// I confess I copy and pasted this from StackOverflow.com

public class StreamReader  {
    let encoding = String.Encoding.utf8
    let chunkSize = 4096
    var fileHandle: FileHandle!
    let delimiter = Data(repeating: 10, count: 1)
    var buffer: Data
    var atEof = false

    public struct OpenError: LocalizedError {
        public let path: Path
        public var errorDescription: String? {
            return "could not open: \(path)"
        }
    }

    public convenience init(path: Path) throws {
        guard let fileHandle = FileHandle(forReadingAtPath: path.string) else {
            throw OpenError(path: path)
        }
        self.init(fileHandle: fileHandle)
    }

    public init(fileHandle: FileHandle) {
        self.fileHandle = fileHandle
        self.buffer = Data(capacity: chunkSize)
    }

    deinit {
        close()
    }

    /// Return next line, or nil on EOF.
    func nextLine() -> String? {
        precondition(fileHandle != nil, "Attempt to read from closed file")

        // Read data chunks from file until a line delimiter is found:
        while !atEof {
            if let range = buffer.range(of: delimiter) {
                // Convert complete line (excluding the delimiter) to a string:
                let line = String(data: buffer.subdata(in: 0..<range.lowerBound), encoding: encoding)
                // Remove line (and the delimiter) from the buffer:
                buffer.removeSubrange(0..<range.upperBound)
                return line
            }
            let tmpData = fileHandle.readData(ofLength: chunkSize)
            if tmpData.count > 0 {
                buffer.append(tmpData)
            } else {
                // EOF or read error.
                atEof = true
                if buffer.count > 0 {
                    // Buffer contains last line in file (not terminated by delimiter).
                    let line = String(data: buffer as Data, encoding: encoding)
                    buffer.count = 0
                    return line
                }
            }
        }
        return nil
    }

    /// Start reading from the beginning of file.
    func rewind() -> Void {
        fileHandle.seek(toFileOffset: 0)
        buffer.count = 0
        atEof = false
    }

    /// Close the underlying file. No reading must be done after calling this method.
    func close() -> Void {
        fileHandle?.closeFile()
        fileHandle = nil
    }
}

extension StreamReader: Sequence {
    public func makeIterator() -> AnyIterator<String> {
        return AnyIterator {
            return self.nextLine()
        }
    }
}
