import AppKit
import DorisCore
import DorisIPC

@objc(DorisPushNotificationCommand)
final class DorisPushNotificationCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        guard let args = evaluatedArguments else { return false }
        let title = (args["title"] as? String) ?? ""
        let body = args["body"] as? String
        let modeString = (args["mode"] as? String) ?? "banner"
        let mode = DisplayMode(rawValue: modeString) ?? .banner

        // Optional source / level / click-url — added to support routing
        // per-app finishing notifications (Claude, ChatGPT, Codex, ...)
        // and a click-through that opens the originating app via its
        // URL scheme. Unknown values silently fall back to safe defaults
        // so older AppleScript callers keep working.
        let source = (args["source"] as? String)
            .flatMap { SourceKind(rawValue: $0) } ?? .manual
        let level = (args["level"] as? String)
            .flatMap { EventLevel(rawValue: $0) } ?? .info
        let clickAction: ClickAction? = (args["click url"] as? String)
            .flatMap { URL(string: $0) }
            .map { .openURL($0) }

        let payload = IPCNotifyPayload(
            title: title,
            body: body,
            displayMode: mode,
            source: source,
            level: level,
            clickAction: clickAction
        )
        let request = IPCRequest(kind: .notify, payload: .notify(payload))
        try? IPCDirectory.ensureDirectories()
        do {
            try IPCWriter.enqueue(request)
            IPCWriter.kick()
            return true
        } catch {
            scriptErrorNumber = -1
            scriptErrorString = "doris: enqueue failed: \(error.localizedDescription)"
            return false
        }
    }
}

@objc(DorisMakeNoteCommand)
final class DorisMakeNoteCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        guard let args = evaluatedArguments else { return false }
        let properties = args["KeyDictionary"] as? [String: Any] ?? args
        let title = (properties["title"] as? String) ?? ""
        let body = (properties["body"] as? String) ?? ""
        let folder = properties["folder"] as? String
        let payload = IPCNoteAddPayload(title: title, body: body, folderName: folder)
        let request = IPCRequest(kind: .noteAdd, payload: .noteAdd(payload))
        try? IPCDirectory.ensureDirectories()
        do {
            try IPCWriter.enqueue(request)
            IPCWriter.kick()
            return true
        } catch {
            return false
        }
    }
}

@objc(DorisDismissMessageCommand)
final class DorisDismissMessageCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        guard let args = evaluatedArguments,
              let idStr = args["id"] as? String,
              let uuid = UUID(uuidString: idStr) else { return false }
        let request = IPCRequest(kind: .eventsDismiss, payload: .eventsDismiss(messageID: uuid))
        try? IPCDirectory.ensureDirectories()
        try? IPCWriter.enqueue(request)
        IPCWriter.kick()
        return true
    }
}
