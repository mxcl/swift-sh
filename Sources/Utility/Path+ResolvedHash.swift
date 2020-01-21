import Foundation
import Path
import CryptoSwift

extension Path {
    public var resolvedHash: String {
        let destination: String
        do {
            destination = try realpath().string
        } catch {
            destination = string
        }
        return destination.md5()
    }
}
