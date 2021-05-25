import struct Foundation.URLComponents
import struct Foundation.CharacterSet
import struct Foundation.URL
import Path

extension ImportSpecification.DependencyName: Codable {
    enum E: Error {
        case invalidDependencySpecification(String)
        case invalidGitHubUsername(String)
    }

    init(rawValue string: String, importName: String, from input: Script.Input) throws {
        guard !string.hasPrefix("git@") else {
            self = .scp(string)
            return
        }
        
        func mangleGitHubUsername(_ input: String) -> String {
            // GitHub allows using `.` when creating usernames/orgs but converts it to `-` so as a convenience we do the same
            return input.replacingOccurrences(of: ".", with: "-")
        }
         
        guard !string.hasPrefix("@") else {
            //FIXME strictly not a thorough github username check
            //NOTE the `.` is not actually allowed, but GitHub allows using it when creating usernames/orgs but converts it to `-` so we must do the same
            let validCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-.")
            let username = String(string.dropFirst())
            guard CharacterSet(charactersIn: username).isSubset(of: validCharacters) else {
                throw E.invalidGitHubUsername(username)
            }
            self = .github(user: mangleGitHubUsername(username), repo: importName)
            return
        }

        let string = string.trimmingCharacters(in: .whitespaces)
        var ccmaybe = URLComponents(string: string)
        if ccmaybe == nil,
           let encodedString = string.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) {
            ccmaybe = URLComponents(string: encodedString)
        }
        guard let cc = ccmaybe else {
            throw E.invalidDependencySpecification(string)
        }

        if cc.scheme == nil {
            if let p = Path(cc.path), p.exists {
                self = .local(p)
                return
            }

            if cc.path.hasPrefix(".") || cc.path.hasPrefix("..") {
                let localRelativePathPrefix: Path
                switch input {
                case .path(let path):
                    localRelativePathPrefix = path.parent
                case .string:
                    localRelativePathPrefix = Path(Path.cwd)
                }
                let localRelativePath = localRelativePathPrefix/cc.path
                if localRelativePath.exists {
                    self = .local(localRelativePath)
                    return
                }
            }

            guard let (user, repo) = pair(cc.path) else {
                throw E.invalidDependencySpecification(string)
            }
            self = .github(user: mangleGitHubUsername(user), repo: repo)
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
    
    var packageName: String? {
        guard let basename = urlString.split(separator: "/").last else { return nil }
        if basename.suffix(4) == ".git" {
            return String(basename.dropLast(4))
        } else {
            return String(basename)
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
