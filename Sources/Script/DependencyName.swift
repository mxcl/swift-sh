import struct Foundation.URLComponents
import struct Foundation.CharacterSet
import struct Foundation.URL
import Path

extension ImportSpecification.DependencyName: Codable {
    enum E: Error {
        case invalidDependencySpecification(String)
        case invalidGitHubUsername(String)
    }

    init(rawValue string: String, importName: String) throws {
        guard !string.hasPrefix("git@") else {
            self = .scp(string)
            return
        }
        guard !string.hasPrefix("@") else {
            // strictly not a thorough github username check
            let validCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-.")
            let username = String(string.dropFirst())
            guard CharacterSet(charactersIn: username).isSubset(of: validCharacters) else {
                throw E.invalidGitHubUsername(username)
            }
            self = .github(user: username, repo: importName)
            return
        }
        guard let cc = URLComponents(string: string) else {
            throw E.invalidDependencySpecification(string)
        }
        if cc.scheme == nil {
            if let p = Path(cc.path), p.exists {
                self = .local(p)
                return
            }

            if cc.path.hasPrefix(".") || cc.path.hasPrefix("..") {
                let localRelativePath = Path.cwd/cc.path
                if localRelativePath.exists {
                    self = .local(localRelativePath)
                    return
                }
            }

            guard let (user, repo) = pair(cc.path) else {
                throw E.invalidDependencySpecification(string)
            }
            self = .github(user: user, repo: repo)
        } else if let url = cc.url {
            self = .url(url)
        } else {
            throw E.invalidDependencySpecification(string)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let str = try container.decode(String.self)

        if str.starts(with: "git@") {
            self = .scp(str)
        } else if let cc = URLComponents(string: str), cc.host == "github.com", let (user, repo) = pair(cc) {
            self = .github(user: user, repo: repo)
        } else if let url = URL(string: str), url.scheme != nil {
            self = .url(url)
        } else if let p = Path(str), p.exists {
            self = .local(p)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid DependencyName")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(urlString)
    }

    var urlString: String {
        switch self {
        case .github(let user, let repo):
            return "https://github.com/\(user)/\(repo).git"
        case .url(let url):
            return url.absoluteString
        case .scp(let str):
            return str
        case .local(let path):
            return path.string
        }
    }
}

private func pair<S: StringProtocol>(_ path: S) -> (String, String)? {
    let parts = path.split(separator: "/")
    if parts.count == 2 {
        return (String(parts[0]), String(parts[1]))
    } else {
        return nil
    }
}

private func pair(_ cc: URLComponents) -> (String, String)? {
    guard cc.host == "github.com", cc.scheme == "https" else {
        return nil
    }
    guard let (user, repo) = pair(cc.path) else {
        return nil
    }
    if repo.hasSuffix(".git") {
        return (user, String(repo.dropLast(4)))
    } else {
        return (user, repo)
    }
}
