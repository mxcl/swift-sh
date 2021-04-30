import Foundation
import Path

import var CommonCrypto.CC_MD5_DIGEST_LENGTH
import func CommonCrypto.CC_MD5
import typealias CommonCrypto.CC_LONG


extension Path {
    public var resolvedHash: String {
        let destination: String
        do {
            destination = try realpath().string
        } catch {
            destination = string
        }
        return destination.MD5()
    }
}


extension String {
    // from https://stackoverflow.com/a/32166735/145108
    // modified to be an instance method that returns a string
    func MD5() -> String {
            let length = Int(CC_MD5_DIGEST_LENGTH)
            let messageData = self.data(using:.utf8)!
            var digestData = Data(count: length)

            _ = digestData.withUnsafeMutableBytes { digestBytes -> UInt8 in
                messageData.withUnsafeBytes { messageBytes -> UInt8 in
                    if let messageBytesBaseAddress = messageBytes.baseAddress, let digestBytesBlindMemory = digestBytes.bindMemory(to: UInt8.self).baseAddress {
                        let messageLength = CC_LONG(messageData.count)
                        CC_MD5(messageBytesBaseAddress, messageLength, digestBytesBlindMemory)
                    }
                    return 0
                }
            }
            let digestString = digestData.map { String(format: "%02hhx", $0) }.joined()
            return digestString
        }
}
