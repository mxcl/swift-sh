import Foundation
#if os(Linux)
import Glibc
#endif

public struct Path: Equatable, Hashable, Comparable {
    public let string: String

    public var `extension`: String {
        return (string as NSString).pathExtension
    }

    /// - Note: always returns a valid Path, Path.root.parent *is* Path.root
    public var parent: Path {
        return Path(string: (string as NSString).deletingLastPathComponent)
    }

    public func basename(dropExtension: Bool = false) -> String {
        let str = string as NSString
        if !dropExtension {
            return str.lastPathComponent
        } else {
            let ext = str.pathExtension
            if !ext.isEmpty {
                return String(str.lastPathComponent.dropLast(ext.count + 1))
            } else {
                return str.lastPathComponent
            }
        }
    }

    public var isDirectory: Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: string, isDirectory: &isDir) && isDir.boolValue
    }

    public var isFile: Bool {
        var isDir: ObjCBool = true
        return FileManager.default.fileExists(atPath: string, isDirectory: &isDir) && !isDir.boolValue
    }

    public var isExecutable: Bool {
        return FileManager.default.isExecutableFile(atPath: string)
    }

    public var exists: Bool {
        return FileManager.default.fileExists(atPath: string)
    }

    public var url: URL {
        return URL(fileURLWithPath: string as String)
    }

    public static var cwd: Path {
        return Path(string: FileManager.default.currentDirectoryPath)
    }

    public static var root: Path {
        return Path(string: "/")
    }

    public static var home: Path {
        return Path(string: NSHomeDirectory())
    }

    //TODO another variant that returns `nil` if result would start with `..`
    public func relative(to base: Path) -> String {
        // Split the two paths into their components.
        // FIXME: The is needs to be optimized to avoid unncessary copying.
        let pathComps = (string as NSString).pathComponents
        let baseComps = (base.string as NSString).pathComponents

        // It's common for the base to be an ancestor, so try that first.
        if pathComps.starts(with: baseComps) {
            // Special case, which is a plain path without `..` components.  It
            // might be an empty path (when self and the base are equal).
            let relComps = pathComps.dropFirst(baseComps.count)
            return relComps.joined(separator: "/")
        } else {
            // General case, in which we might well need `..` components to go
            // "up" before we can go "down" the directory tree.
            var newPathComps = ArraySlice(pathComps)
            var newBaseComps = ArraySlice(baseComps)
            while newPathComps.prefix(1) == newBaseComps.prefix(1) {
                // First component matches, so drop it.
                newPathComps = newPathComps.dropFirst()
                newBaseComps = newBaseComps.dropFirst()
            }
            // Now construct a path consisting of as many `..`s as are in the
            // `newBaseComps` followed by what remains in `newPathComps`.
            var relComps = Array(repeating: "..", count: newBaseComps.count)
            relComps.append(contentsOf: newPathComps)
            return relComps.joined(separator: "/")
        }
    }

    public enum E: Swift.Error {
        case cannotEnumerate
        case enumerationError(URL, Swift.Error)
        case mkstemp
    }

    public struct Entry {
        public enum Kind {
            case file
            case directory
        }
        public let kind: Kind
        public let path: Path
    }

    public func mkdir() throws {
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false, attributes: nil)
        } catch CocoaError.Code.fileWriteFileExists {
            // noop
        }
    }

    public func mkpath() throws {
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        } catch CocoaError.Code.fileWriteFileExists {
            // noop
        }
    }

    public static func mktemp<T>(body: (Path) throws -> T) throws -> T {
      #if !os(Linux)
        let url = try FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: URL(fileURLWithPath: "/"), create: true)
      #else
        let envs = ProcessInfo.processInfo.environment
        let env = envs["TMPDIR"] ?? envs["TEMP"] ?? envs["TMP"] ?? "/tmp"
        let dir = Path.root/env/"swift-sh.XXXXXX"
        var template = [UInt8](dir.string.utf8).map({ Int8($0) }) + [Int8(0)]
        guard mkdtemp(&template) != nil else { throw CocoaError.error(.featureUnsupported) }
        let url = URL(fileURLWithPath: String(cString: template))
      #endif
        defer { _ = try? FileManager.default.removeItem(at: url) }
        return try body(Path(string: url.path))
    }

    /// same as the `ls` command ∴ is ”shallow”
    public func ls() throws -> [Entry] {
        let relativePaths = try FileManager.default.contentsOfDirectory(atPath: string)
        func convert(relativePath: String) -> Entry {
            let path = self/relativePath
            return Entry(kind: path.isDirectory ? .directory : .file, path: path)
        }
        return relativePaths.map(convert)
    }

    public func join(_ part: String) -> Path {
        return self/part
    }

    public func cd(body: () throws -> Void) rethrows {
        let prev = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(string)
        try body()
        FileManager.default.changeCurrentDirectoryPath(prev)
    }

    public static func < (lhs: Path, rhs: Path) -> Bool {
        return lhs.string.compare(rhs.string, locale: .current) == .orderedAscending
    }

    /// - Note: If file is already locked, does nothing
    /// - Note: If file doesn’t exist, throws
    @discardableResult
    public func lock() throws -> Path {
        var attrs = try FileManager.default.attributesOfItem(atPath: string)
        let b = attrs[.immutable] as? Bool ?? false
        if !b {
            attrs[.immutable] = true
            try FileManager.default.setAttributes(attrs, ofItemAtPath: string)
        }
        return self
    }

    @discardableResult
    public func chmod(_ octal: Int) throws -> Path {
        try FileManager.default.setAttributes([.posixPermissions: octal], ofItemAtPath: string)
        return self
    }

    /// - Note: If file isn‘t locked, does nothing
    /// - Note: If file doesn’t exist, does nothing
    @discardableResult
    public func unlock() throws -> Path {
        var attrs: [FileAttributeKey: Any]
        do {
            attrs = try FileManager.default.attributesOfItem(atPath: string)
        } catch CocoaError.fileReadNoSuchFile {
            return self
        }
        let b = attrs[.immutable] as? Bool ?? false
        if b {
            attrs[.immutable] = false
            try FileManager.default.setAttributes(attrs, ofItemAtPath: string)
        }
        return self
    }

    public var isWritable: Bool {
        return FileManager.default.isWritableFile(atPath: string)
    }

    /// - Returns: modification-time or creation-time if none
    public var mtime: Date {
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: string)
            return attrs[.modificationDate] as? Date ?? attrs[.creationDate] as? Date ?? Date()
        } catch {
            //TODO print(error)
            return Date()
        }
    }

    /// - Note: If file doesn’t exist, creates file
    /// - Note: If file is not writable, makes writable first, resetting permissions after the write
    @discardableResult
    public func replaceContents(with contents: String, atomically: Bool = false, encoding: String.Encoding = .utf8) throws -> Path {
        let resetPerms: Int?
        if exists, !isWritable {
            resetPerms = try FileManager.default.attributesOfItem(atPath: string)[.posixPermissions] as? Int
            let perms = resetPerms ?? 0o777
            try chmod(perms | 0o200)
        } else {
            resetPerms = nil
        }

        defer {
            _ = try? resetPerms.map(self.chmod)
        }

        try contents.write(to: self)

        return self
    }

    @discardableResult
    public func copy(to: Path, overwrite: Bool = false) throws -> Path {
        return try FileManager.default.copyItem(at: self, to: to, overwrite: overwrite)
    }

    public func delete() throws {
        try FileManager.default.removeItem(at: self)
    }
}

public extension CodingUserInfoKey {
    static let relativePath = CodingUserInfoKey(rawValue: "dev.mxcl.Cake.Path.relative")!
}

extension Path: Codable {
    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        if value.hasPrefix("/") {
            string = value
        } else {
            guard let root = decoder.userInfo[.relativePath] as? Path else {
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Path cannot decode a relative path if `userInfo[.relativePath]` not set to a Path object."))
            }
            string = (root/value).string
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let root = encoder.userInfo[.relativePath] as? Path {
            try container.encode(relative(to: root))
        } else {
            try container.encode(string)
        }
    }
}

public func /(lhs: Path, rhs: String) -> Path {
    //TODO standardizingPath does more than we want really (eg tilde expansion)
    let str = (lhs.string as NSString).appendingPathComponent(rhs)
    return Path(string: (str as NSString).standardizingPath)
}

public extension FileManager {
    @inlinable
    @discardableResult
    func copyItem(at: Path, to: Path, overwrite: Bool = false) throws -> Path {
        var to = to
        if to.isDirectory {
            to = to/at.basename()
        }
        if overwrite, to.exists {
            try removeItem(at: to)
        }
        try copyItem(atPath: at.string, toPath: to.string)
        return to
    }

    @inlinable
    @discardableResult
    func removeItem(at: Path) throws -> Path {
        try removeItem(atPath: at.string)
        return at
    }
}

public extension String {
    init(contentsOf path: Path) throws {
        try self.init(contentsOfFile: path.string)
    }

    /// - Returns: `to` to allow chaining
    @inlinable
    @discardableResult
    func write(to: Path, atomically: Bool = false, encoding: String.Encoding = .utf8) throws -> Path {
        try write(toFile: to.string, atomically: atomically, encoding: encoding)
        return to
    }
}

public extension Data {
    @inlinable
    init(contentsOf path: Path) throws {
        try self.init(contentsOf: path.url)
    }

    /// - Returns: `to` to allow chaining
    @inlinable
    @discardableResult
    func write(to: Path, atomically: Bool = false) throws -> Path {
        let opts: NSData.WritingOptions
        if atomically {
		  #if os(Linux)
            opts = .atomic
		  #else
            opts = .atomicWrite
		  #endif
        } else {
            opts = []
        }
        try write(to: to.url, options: opts)
        return to
    }
}

public extension Bundle {
    @inlinable
    func path(forResource: String, ofType: String?) -> Path {
        let f: (String?, String?) -> String? = path(forResource:ofType:)
        let str = f(forResource, ofType)
        return Path.root/str!
    }

    @inlinable
    public var sharedFrameworks: Path {
        return Path.root/sharedFrameworksPath!
    }

    @inlinable
    public var resources: Path {
        return Path.root/resourcePath!
    }

    @inlinable
    public var path: Path {
        return Path.root/bundlePath
    }
}

public extension CommandLine {
    static func path(at: Int) -> Path {
        let str = arguments[at]

        if str.hasPrefix("/") {
            return Path(string: str)
        } else {
            return Path.cwd/str
        }
    }
}

public extension Array where Element == Path.Entry {
    var directories: [Path] {
        return compactMap {
            $0.kind == .directory ? $0.path : nil
        }
    }

    func files(withExtension ext: String) -> [Path] {
        return compactMap {
            $0.kind == .file && $0.path.extension == ext ? $0.path : nil
        }
    }
}
