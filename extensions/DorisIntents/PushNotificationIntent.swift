import AppIntents
import DorisIPC

struct PushNotificationIntent: AppIntent {
    static var title: LocalizedStringResource = "Push Notification"
    static var description = IntentDescription("Send a notification to doris from Shortcuts.")

    @Parameter(title: "Title")
    var title: String

    @Parameter(title: "Body")
    var body: String?

    @Parameter(title: "Mode")
    var mode: DorisDisplayMode

    @Parameter(title: "Cross-device")
    var crossDevice: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Push \(\.$title) (\(\.$mode))")
    }

    func perform() async throws -> some IntentResult {
        let payload = IPCNotifyPayload(
            title: title,
            body: body,
            displayMode: mode == .fix ? .fix : .banner,
            source: .manual,
            sourceAppId: "shortcut",
            broadcast: crossDevice ? .allDevices : .local
        )
        let request = IPCRequest(kind: .notify, payload: .notify(payload))
        try IPCDirectory.ensureDirectories()
        try IPCWriter.enqueue(request)
        IPCWriter.kick()
        return .result()
    }
}

enum DorisDisplayMode: String, AppEnum {
    case banner, fix
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Display Mode"
    static var caseDisplayRepresentations: [DorisDisplayMode: DisplayRepresentation] = [
        .banner: "Banner",
        .fix: "Fix (persistent)"
    ]
}
