import Foundation
import KhanIPC
import SwiftData

public protocol NotificationPresenter: AnyObject, Sendable {
    func presentBanner(_ message: PresentableMessage)
    func presentFix(_ message: PresentableMessage)
    func dismiss(messageID: UUID)
}

public protocol OutboxPublishing: AnyObject, Sendable {
    func publish(_ payload: IPCNotifyPayload, originDeviceID: UUID, originalMessageID: UUID) async throws
}

public struct PresentableMessage: Sendable, Identifiable {
    public let id: UUID
    public let title: String
    public let body: String?
    public let source: SourceKind
    public let sourceAppId: String?
    public let iconName: String?
    public let displayMode: DisplayMode
    public let receivedAt: Date
    public let clickAction: ClickAction?

    public init(
        id: UUID,
        title: String,
        body: String?,
        source: SourceKind,
        sourceAppId: String?,
        iconName: String?,
        displayMode: DisplayMode,
        receivedAt: Date,
        clickAction: ClickAction?
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.source = source
        self.sourceAppId = sourceAppId
        self.iconName = iconName
        self.displayMode = displayMode
        self.receivedAt = receivedAt
        self.clickAction = clickAction
    }
}

@MainActor
public final class NotificationRouter {
    private let modelContainer: ModelContainer
    private let dedup: DedupCache
    private weak var presenter: NotificationPresenter?
    private weak var outbox: OutboxPublishing?

    public init(modelContainer: ModelContainer, dedup: DedupCache = DedupCache()) {
        self.modelContainer = modelContainer
        self.dedup = dedup
    }

    public func setPresenter(_ presenter: NotificationPresenter?) {
        self.presenter = presenter
    }

    public func setOutbox(_ outbox: OutboxPublishing?) {
        self.outbox = outbox
    }

    public func handle(_ request: IPCRequest) async {
        guard await dedup.record(request.id) else {
            KhanLog.router.debug("dropping duplicate request \(request.id, privacy: .public)")
            return
        }

        switch request.payload {
        case .notify(let payload):
            await ingestNotify(payload, requestID: request.id)
        case .noteAdd(let payload):
            await ingestNoteAdd(payload)
        case .inboxDismiss(let id):
            await mutateMessage(id) { $0.state = .dismissed }
        case .inboxDone(let id):
            await mutateMessage(id) { $0.state = .actioned }
        case .inboxList, .sync, .ping:
            break
        }
    }

    private func ingestNotify(_ payload: IPCNotifyPayload, requestID: UUID) async {
        let context = ModelContext(modelContainer)
        let settings = (try? loadSettings(in: context)) ?? UserSettings()
        let originDevice = DeviceIdentity.current()
        let allowlist = settings.cliSourceAllowlist
        let sourceID = payload.sourceAppId ?? "cliGeneric"

        let allowedBySource = allowlist.contains { Glob.match($0, candidate: sourceID) }
        if !allowedBySource && !allowlist.contains("*") {
            KhanLog.router.notice("source \(sourceID, privacy: .public) blocked by allowlist")
            return
        }

        let muted = settings.muteRules.contains { $0.matches(sourceAppId: sourceID, mode: payload.displayMode) }

        let message = Message(
            id: requestID,
            title: payload.title,
            bodyMarkdown: payload.body,
            source: payload.source,
            sourceAppId: payload.sourceAppId,
            iconName: payload.iconName ?? payload.source.sfSymbol,
            displayMode: payload.displayMode,
            state: .inbox,
            clickAction: payload.clickAction,
            originDeviceId: originDevice.uuidString
        )
        context.insert(message)
        try? context.save()

        let presentable = PresentableMessage(
            id: message.id,
            title: message.title,
            body: message.bodyMarkdown,
            source: payload.source,
            sourceAppId: payload.sourceAppId,
            iconName: message.iconName,
            displayMode: payload.displayMode,
            receivedAt: message.receivedAt,
            clickAction: payload.clickAction
        )

        if !muted {
            switch payload.displayMode {
            case .banner: presenter?.presentBanner(presentable)
            case .fix:    presenter?.presentFix(presentable)
            }
        }

        switch payload.broadcast {
        case .local: break
        case .allDevices, .device:
            if let outbox = self.outbox {
                Task.detached { [outbox, payload, originDevice, requestID] in
                    do {
                        try await outbox.publish(payload, originDeviceID: originDevice, originalMessageID: requestID)
                    } catch {
                        KhanLog.push.error("outbox publish failed: \(String(describing: error), privacy: .public)")
                    }
                }
            }
        }
    }

    private func ingestNoteAdd(_ payload: IPCNoteAddPayload) async {
        let context = ModelContext(modelContainer)
        let folder = try? findOrCreateFolder(named: payload.folderName, in: context)
        let note = Note(title: payload.title, bodyMarkdown: payload.body, folder: folder)
        var noteTags: [Tag] = note.tags ?? []
        for tagName in payload.tags {
            let tag = (try? findOrCreateTag(named: tagName, in: context)) ?? Tag(name: tagName)
            context.insert(tag)
            noteTags.append(tag)
        }
        note.tags = noteTags
        context.insert(note)
        try? context.save()
    }

    private func mutateMessage(_ id: UUID, _ mutate: (Message) -> Void) async {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<Message>(predicate: #Predicate { $0.id == id })
        if let message = try? context.fetch(descriptor).first {
            mutate(message)
            try? context.save()
            presenter?.dismiss(messageID: id)
        }
    }

    private func loadSettings(in context: ModelContext) throws -> UserSettings {
        let descriptor = FetchDescriptor<UserSettings>()
        if let existing = try context.fetch(descriptor).first { return existing }
        let new = UserSettings()
        context.insert(new)
        try context.save()
        return new
    }

    private func findOrCreateFolder(named name: String?, in context: ModelContext) throws -> Folder? {
        guard let name, !name.isEmpty else { return nil }
        let descriptor = FetchDescriptor<Folder>(predicate: #Predicate { $0.name == name })
        if let existing = try context.fetch(descriptor).first { return existing }
        let folder = Folder(name: name)
        context.insert(folder)
        return folder
    }

    private func findOrCreateTag(named name: String, in context: ModelContext) throws -> Tag {
        let descriptor = FetchDescriptor<Tag>(predicate: #Predicate { $0.name == name })
        if let existing = try context.fetch(descriptor).first { return existing }
        return Tag(name: name)
    }
}
