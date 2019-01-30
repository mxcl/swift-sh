import Foundation

public extension NSRegularExpression {
    func firstMatch(in str: String) -> NSTextCheckingResult? {
        let range = NSRange(location: 0, length: str.utf16.count)
        return firstMatch(in: str, range: range)
    }
}

public extension String {
    subscript(range: NSRange) -> Substring {
        return self[Range(range, in: self)!]
    }
}
