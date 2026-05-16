import Foundation

public enum SourceKind: String, Codable, CaseIterable, Sendable {
    case claudeCode
    case codex
    case chatgpt
    case trae
    case vscode
    case feishu
    case cliGeneric
    case scheduledJob
    case userMemo
    case share
    case manual

    public var displayName: String {
        switch self {
        case .claudeCode:   return "Claude Code"
        case .codex:        return "Codex"
        case .chatgpt:      return "ChatGPT"
        case .trae:         return "Trae"
        case .vscode:       return "VS Code"
        case .feishu:       return "飞书"
        case .cliGeneric:   return "CLI"
        case .scheduledJob: return "Scheduled"
        case .userMemo:     return "Memo"
        case .share:        return "Share"
        case .manual:       return "Manual"
        }
    }

    public var sfSymbol: String {
        switch self {
        case .claudeCode:   return "sparkle"
        case .codex:        return "chevron.left.forwardslash.chevron.right"
        case .chatgpt:      return "bubble.left.and.bubble.right.fill"
        case .trae:         return "wand.and.stars"
        case .vscode:       return "curlybraces.square.fill"
        case .feishu:       return "person.2.wave.2.fill"
        case .cliGeneric:   return "terminal"
        case .scheduledJob: return "clock"
        case .userMemo:     return "note.text"
        case .share:        return "square.and.arrow.up"
        case .manual:       return "hand.point.up.left"
        }
    }
}

/// Severity / urgency of an event. Drives list styling (color stripe,
/// icon tint) so `critical` items pop out, `reminder` looks like a soft
/// nudge, `info` fades into the background. Wire-stable string raws so
/// the level survives IPC + iCloud sync as plain JSON.
public enum EventLevel: String, Codable, CaseIterable, Sendable {
    case critical
    case reminder
    case info

    public var displayName: String {
        switch self {
        case .critical: return "Critical"
        case .reminder: return "Reminder"
        case .info:     return "Info"
        }
    }

    public var sfSymbol: String {
        switch self {
        case .critical: return "exclamationmark.octagon.fill"
        case .reminder: return "bell.fill"
        case .info:     return "info.circle.fill"
        }
    }
}

public enum DisplayMode: String, Codable, Sendable {
    case banner
    case fix
}

/// State of an event in the event list.
///
/// `active` keeps the wire/storage rawValue as `"inbox"` for backwards
/// compatibility with rows already in the SwiftData store + CloudKit
/// records (the term changed from "inbox" to "events" in the UI, but
/// migrating the persisted enum value would invalidate every existing
/// record). New code should reference `.active`.
public enum MessageState: String, Codable, Sendable {
    case active = "inbox"
    case dismissed
    case actioned
    case snoozed
}

public enum BroadcastScope: Codable, Equatable, Sendable {
    case local
    case allDevices
    case device(id: UUID)

    private enum CodingKeys: String, CodingKey { case kind, deviceID }
    private enum Kind: String, Codable { case local, allDevices, device }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .kind)
        switch kind {
        case .local:      self = .local
        case .allDevices: self = .allDevices
        case .device:
            let id = try c.decode(UUID.self, forKey: .deviceID)
            self = .device(id: id)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .local:
            try c.encode(Kind.local, forKey: .kind)
        case .allDevices:
            try c.encode(Kind.allDevices, forKey: .kind)
        case .device(let id):
            try c.encode(Kind.device, forKey: .kind)
            try c.encode(id, forKey: .deviceID)
        }
    }
}

public enum ClickAction: Codable, Equatable, Sendable {
    case openURL(URL)
    case openNote(id: UUID)
    case runIntent(name: String)
    case markDone

    private enum CodingKeys: String, CodingKey { case kind, url, noteID, intentName }
    private enum Kind: String, Codable { case openURL, openNote, runIntent, markDone }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .kind)
        switch kind {
        case .openURL:
            let url = try c.decode(URL.self, forKey: .url)
            self = .openURL(url)
        case .openNote:
            let id = try c.decode(UUID.self, forKey: .noteID)
            self = .openNote(id: id)
        case .runIntent:
            let name = try c.decode(String.self, forKey: .intentName)
            self = .runIntent(name: name)
        case .markDone:
            self = .markDone
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .openURL(let url):
            try c.encode(Kind.openURL, forKey: .kind)
            try c.encode(url, forKey: .url)
        case .openNote(let id):
            try c.encode(Kind.openNote, forKey: .kind)
            try c.encode(id, forKey: .noteID)
        case .runIntent(let name):
            try c.encode(Kind.runIntent, forKey: .kind)
            try c.encode(name, forKey: .intentName)
        case .markDone:
            try c.encode(Kind.markDone, forKey: .kind)
        }
    }
}
