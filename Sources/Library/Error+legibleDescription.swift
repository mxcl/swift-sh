import Foundation

extension Error {
#if os(Linux)
    public var legibleDescription: String {
        if let err = self as? LocalizedError, let msg = err.errorDescription, !msg.hasPrefix("The operation couldn’t be completed.") {
            return msg
        } else {
            return "\(type(of: self)).\(self)"
        }
    }
#else
    public var legibleDescription: String {
        switch errorType {
        case .swiftError(.enum?):
            return "\(type(of: self)).\(self)"
        case .swiftError:
            return String(describing: self)
        case .swiftLocalizedError(let msg):
            return msg
        case .nsError(_, "kCLErrorDomain", 0):
            return "The location could not be determined."
        // ^^ Apple don’t provide a localized description for this
        case .nsError(let nsError, _, _):
            if !localizedDescription.hasPrefix("The operation couldn’t be completed.") {
                return localizedDescription
                //FIXME ^^ for non-EN
            } else if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
                return underlyingError.legibleDescription
            } else {
                // usually better than the localizedDescription, but not pretty
                return nsError.debugDescription
            }
        }
    }

    private var errorType: ErrorType {
        if String(cString: object_getClassName(self)) != "_SwiftNativeNSError" {
            // ^^ ∵ otherwise implicit bridging implicitly casts as for other tests
            // ^^ ∵ localizedDescription for most custom Swift Errors just says “the operation failed to complete”
            let nserr = self as NSError
            return .nsError(nserr, domain: nserr.domain, code: nserr.code)
        } else if let err = self as? LocalizedError, let msg = err.errorDescription {
            return .swiftLocalizedError(msg)
        } else {
            return .swiftError(Mirror(reflecting: self).displayStyle)
        }
    }
#endif
}

#if !os(Linux)
private enum ErrorType {
    case nsError(NSError, domain: String, code: Int)
    case swiftLocalizedError(String)
    case swiftError(Mirror.DisplayStyle?)
}
#endif
