import Foundation
import Path

public class TemporaryDirectory {
    public let url: URL
    public var path: Path { return Path.root/url.path }

    /**
     Creates a new temporary directory.

     The directory is recursively deleted when this object deallocates.

     If you need a temporary directory on a specific volume use the `appropriateFor`
     parameter.

     - Important: If you are moving a file, ensure to use the `appropriateFor`
     parameter, since it is volume aware and moving the file across volumes will take
     exponentially longer!
     - Important: The `appropriateFor` parameter does not work on Linux.
     - Parameter appropriateFor: The temporary directory will be located on this
     volume.
    */
    public init(appropriateFor: URL? = nil) throws {
      #if !os(Linux)
        let appropriate: URL
        if let appropriateFor = appropriateFor {
            appropriate = appropriateFor
        } else if #available(OSX 10.12, iOS 10, tvOS 10, watchOS 3, *) {
            appropriate = FileManager.default.temporaryDirectory
        } else {
            appropriate = URL(fileURLWithPath: NSTemporaryDirectory())
        }
        url = try FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: appropriate, create: true)
      #else
        let envs = ProcessInfo.processInfo.environment
        let env = envs["TMPDIR"] ?? envs["TEMP"] ?? envs["TMP"] ?? "/tmp"
        let dir = Path.root/env/"swift-sh.XXXXXX"
        var template = [UInt8](dir.string.utf8).map({ Int8($0) }) + [Int8(0)]
        guard mkdtemp(&template) != nil else { throw CocoaError.error(.featureUnsupported) }
        url = URL(fileURLWithPath: String(cString: template))
      #endif
    }

    deinit {
        _ = try? FileManager.default.removeItem(at: url)
    }
}

public extension Path {
    static func mktemp<T>(body: (Path) throws -> T) throws -> T {
        let tmp = try TemporaryDirectory()
        return try body(tmp.path)
    }
}
