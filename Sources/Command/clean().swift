import Foundation
import CryptoSwift
import Path

public func clean(_ script: Path?) throws {
    guard let script = script else {
        return try Path.build.delete()
    }

    guard script.isFile else {
        throw CocoaError.error(.fileNoSuchFile)
    }

    let path = Path.build/script.string.md5()
    try path.delete()
}
