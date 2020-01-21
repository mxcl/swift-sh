import Foundation
import Path
import Utility

public func clean(_ script: Path?) throws {
    guard let script = script else {
        return try Path.build.delete()
    }

    guard script.isFile else {
        throw CocoaError.error(.fileNoSuchFile)
    }

    let path = Path.build/script.resolvedHash
    try path.delete()
}
