import Foundation
import DorisIPC
import SwiftData

@Model
public final class Message {
    public var id: UUID = UUID()
    public var title: String = ""
    public var bodyMarkdown: String?
    public var sourceRaw: String = SourceKind.cliGeneric.rawValue
    public var sourceAppId: String?
    public var iconName: String?
    public var receivedAt: Date = Date()
    public var displayModeRaw: String = DisplayMode.banner.rawValue
    public var stateRaw: String = MessageState.inbox.rawValue
    public var snoozedUntil: Date?
    public var clickActionData: Data?
    public var originDeviceId: String = ""
    public var originalMessageId: UUID?

    public var tags: [Tag]? = []

    @Relationship(deleteRule: .cascade, inverse: \Attachment.message)
    public var attachments: [Attachment]? = []

    @Relationship(inverse: \Note.promotedFrom)
    public var promotedNote: Note?

    public init(
        id: UUID = UUID(),
        title: String,
        bodyMarkdown: String? = nil,
        source: SourceKind,
        sourceAppId: String? = nil,
        iconName: String? = nil,
        receivedAt: Date = Date(),
        displayMode: DisplayMode = .banner,
        state: MessageState = .inbox,
        snoozedUntil: Date? = nil,
        clickAction: ClickAction? = nil,
        originDeviceId: String,
        originalMessageId: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.bodyMarkdown = bodyMarkdown
        self.sourceRaw = source.rawValue
        self.sourceAppId = sourceAppId
        self.iconName = iconName
        self.receivedAt = receivedAt
        self.displayModeRaw = displayMode.rawValue
        self.stateRaw = state.rawValue
        self.snoozedUntil = snoozedUntil
        self.originDeviceId = originDeviceId
        self.originalMessageId = originalMessageId
        if let action = clickAction {
            self.clickActionData = try? JSONEncoder().encode(action)
        }
    }

    public var source: SourceKind {
        get { SourceKind(rawValue: sourceRaw) ?? .cliGeneric }
        set { sourceRaw = newValue.rawValue }
    }

    public var displayMode: DisplayMode {
        get { DisplayMode(rawValue: displayModeRaw) ?? .banner }
        set { displayModeRaw = newValue.rawValue }
    }

    public var state: MessageState {
        get { MessageState(rawValue: stateRaw) ?? .inbox }
        set { stateRaw = newValue.rawValue }
    }

    public var clickAction: ClickAction? {
        get {
            guard let data = clickActionData else { return nil }
            return try? JSONDecoder().decode(ClickAction.self, from: data)
        }
        set {
            clickActionData = newValue.flatMap { try? JSONEncoder().encode($0) }
        }
    }
}
