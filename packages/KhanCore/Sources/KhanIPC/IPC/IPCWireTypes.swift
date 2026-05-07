import Foundation

public enum IPCRequestKind: String, Codable, Sendable {
    case notify
    case noteAdd
    case inboxList
    case inboxDismiss
    case inboxDone
    case sync
    case ping
}

public struct IPCRequest: Codable, Sendable {
    public let v: Int
    public let id: UUID
    public let kind: IPCRequestKind
    public let payload: IPCPayload
    public var hmac: String?

    public init(id: UUID = UUID(), kind: IPCRequestKind, payload: IPCPayload) {
        self.v = 1
        self.id = id
        self.kind = kind
        self.payload = payload
        self.hmac = nil
    }
}

public enum IPCPayload: Codable, Sendable {
    case notify(IPCNotifyPayload)
    case noteAdd(IPCNoteAddPayload)
    case inboxList(IPCInboxListPayload)
    case inboxDismiss(messageID: UUID)
    case inboxDone(messageID: UUID)
    case sync
    case ping

    private enum CodingKeys: String, CodingKey { case kind, body }
    private enum K: String, Codable {
        case notify, noteAdd, inboxList, inboxDismiss, inboxDone, sync, ping
    }
    private struct IDBox: Codable { let id: UUID }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(K.self, forKey: .kind)
        switch kind {
        case .notify:
            self = .notify(try c.decode(IPCNotifyPayload.self, forKey: .body))
        case .noteAdd:
            self = .noteAdd(try c.decode(IPCNoteAddPayload.self, forKey: .body))
        case .inboxList:
            self = .inboxList(try c.decode(IPCInboxListPayload.self, forKey: .body))
        case .inboxDismiss:
            self = .inboxDismiss(messageID: try c.decode(IDBox.self, forKey: .body).id)
        case .inboxDone:
            self = .inboxDone(messageID: try c.decode(IDBox.self, forKey: .body).id)
        case .sync:
            self = .sync
        case .ping:
            self = .ping
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .notify(let p):
            try c.encode(K.notify, forKey: .kind)
            try c.encode(p, forKey: .body)
        case .noteAdd(let p):
            try c.encode(K.noteAdd, forKey: .kind)
            try c.encode(p, forKey: .body)
        case .inboxList(let p):
            try c.encode(K.inboxList, forKey: .kind)
            try c.encode(p, forKey: .body)
        case .inboxDismiss(let id):
            try c.encode(K.inboxDismiss, forKey: .kind)
            try c.encode(IDBox(id: id), forKey: .body)
        case .inboxDone(let id):
            try c.encode(K.inboxDone, forKey: .kind)
            try c.encode(IDBox(id: id), forKey: .body)
        case .sync:
            try c.encode(K.sync, forKey: .kind)
        case .ping:
            try c.encode(K.ping, forKey: .kind)
        }
    }
}

public struct IPCNotifyPayload: Codable, Sendable {
    public var title: String
    public var body: String?
    public var iconName: String?
    public var displayMode: DisplayMode
    public var source: SourceKind
    public var sourceAppId: String?
    public var clickAction: ClickAction?
    public var broadcast: BroadcastScope

    public init(
        title: String,
        body: String? = nil,
        iconName: String? = nil,
        displayMode: DisplayMode = .banner,
        source: SourceKind = .cliGeneric,
        sourceAppId: String? = nil,
        clickAction: ClickAction? = nil,
        broadcast: BroadcastScope = .local
    ) {
        self.title = title
        self.body = body
        self.iconName = iconName
        self.displayMode = displayMode
        self.source = source
        self.sourceAppId = sourceAppId
        self.clickAction = clickAction
        self.broadcast = broadcast
    }
}

public struct IPCNoteAddPayload: Codable, Sendable {
    public var title: String
    public var body: String
    public var folderName: String?
    public var tags: [String]

    public init(title: String, body: String = "", folderName: String? = nil, tags: [String] = []) {
        self.title = title
        self.body = body
        self.folderName = folderName
        self.tags = tags
    }
}

public struct IPCInboxListPayload: Codable, Sendable {
    public var source: SourceKind?
    public var sinceSeconds: TimeInterval?
    public var unreadOnly: Bool
    public var limit: Int?
    public var follow: Bool

    public init(source: SourceKind? = nil, sinceSeconds: TimeInterval? = nil, unreadOnly: Bool = false, limit: Int? = nil, follow: Bool = false) {
        self.source = source
        self.sinceSeconds = sinceSeconds
        self.unreadOnly = unreadOnly
        self.limit = limit
        self.follow = follow
    }
}

public struct IPCResponse: Codable, Sendable {
    public var v: Int
    public var requestID: UUID
    public var ok: Bool
    public var error: String?
    public var data: Data?

    public init(requestID: UUID, ok: Bool, error: String? = nil, data: Data? = nil) {
        self.v = 1
        self.requestID = requestID
        self.ok = ok
        self.error = error
        self.data = data
    }
}

public struct IPCInboxRow: Codable, Sendable {
    public let id: UUID
    public let title: String
    public let body: String?
    public let source: SourceKind
    public let sourceAppId: String?
    public let receivedAt: Date
    public let displayMode: DisplayMode
    public let state: MessageState

    public init(id: UUID, title: String, body: String?, source: SourceKind, sourceAppId: String?, receivedAt: Date, displayMode: DisplayMode, state: MessageState) {
        self.id = id
        self.title = title
        self.body = body
        self.source = source
        self.sourceAppId = sourceAppId
        self.receivedAt = receivedAt
        self.displayMode = displayMode
        self.state = state
    }
}

public enum IPCEncoding {
    public static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    public static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
