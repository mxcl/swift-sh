
/// wheter the script has @main
public enum ExecutableTargetMainStyle {
    /// script has @main, script source file cannot be named main.swift, as this would be compilation error
    case mainAttribute
    /// script doesn't have @main, and it's ok to have main.swift file as script source
    case topLevelCode
}
