import protocol Foundation.LocalizedError

//MARK: CommandLine.usage

public extension CommandLine {
    static let usage = """
        swift sh <script> [arguments]
        swift sh eject <script> [-f|--force]
        swift sh edit <script>
        """

    enum Error: LocalizedError {
        case invalidUsage

        public var errorDescription: String? {
            switch self {
            case .invalidUsage:
                return CommandLine.usage
            }
        }
    }
}
