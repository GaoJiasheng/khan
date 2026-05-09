import Foundation

public struct MuteRule: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var sourceAppIdGlob: String      // e.g. "claude-code", "deploy.*", "*"
    public var displayMode: DisplayMode?    // nil = both
    public var silentUntil: Date?

    public init(
        id: UUID = UUID(),
        sourceAppIdGlob: String,
        displayMode: DisplayMode? = nil,
        silentUntil: Date? = nil
    ) {
        self.id = id
        self.sourceAppIdGlob = sourceAppIdGlob
        self.displayMode = displayMode
        self.silentUntil = silentUntil
    }

    public func matches(sourceAppId: String?, mode: DisplayMode) -> Bool {
        if let mine = displayMode, mine != mode { return false }
        if let until = silentUntil, until < Date() { return false }
        return Glob.match(sourceAppIdGlob, candidate: sourceAppId ?? "")
    }
}

public enum Glob {
    public static func match(_ pattern: String, candidate: String) -> Bool {
        if pattern == "*" { return true }
        if pattern == candidate { return true }
        if pattern.contains("*") {
            let regexBody = pattern
                .replacingOccurrences(of: ".", with: "\\.")
                .replacingOccurrences(of: "*", with: ".*")
            let pattern = "^" + regexBody + "$"
            return candidate.range(of: pattern, options: .regularExpression) != nil
        }
        return false
    }
}
