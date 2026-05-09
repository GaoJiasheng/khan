import Foundation

public enum SourceKind: String, Codable, CaseIterable, Sendable {
    case claudeCode
    case cliGeneric
    case scheduledJob
    case userMemo
    case share
    case manual

    public var displayName: String {
        switch self {
        case .claudeCode:   return "Claude Code"
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
        case .cliGeneric:   return "terminal"
        case .scheduledJob: return "clock"
        case .userMemo:     return "note.text"
        case .share:        return "square.and.arrow.up"
        case .manual:       return "hand.point.up.left"
        }
    }
}

public enum DisplayMode: String, Codable, Sendable {
    case banner
    case fix
}

public enum MessageState: String, Codable, Sendable {
    case inbox
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
