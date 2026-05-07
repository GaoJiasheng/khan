import AppKit
import KhanCore
import KhanIPC

@objc(KhanPushNotificationCommand)
final class KhanPushNotificationCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        guard let args = evaluatedArguments else { return false }
        let title = (args["title"] as? String) ?? ""
        let body = args["body"] as? String
        let modeString = (args["mode"] as? String) ?? "banner"
        let mode = DisplayMode(rawValue: modeString) ?? .banner

        let payload = IPCNotifyPayload(title: title, body: body, displayMode: mode, source: .manual)
        let request = IPCRequest(kind: .notify, payload: .notify(payload))
        try? IPCDirectory.ensureDirectories()
        do {
            try IPCWriter.enqueue(request)
            IPCWriter.kick()
            return true
        } catch {
            scriptErrorNumber = -1
            scriptErrorString = "khan: enqueue failed: \(error.localizedDescription)"
            return false
        }
    }
}

@objc(KhanMakeNoteCommand)
final class KhanMakeNoteCommand: NSScriptCommand {
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

@objc(KhanDismissMessageCommand)
final class KhanDismissMessageCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        guard let args = evaluatedArguments,
              let idStr = args["id"] as? String,
              let uuid = UUID(uuidString: idStr) else { return false }
        let request = IPCRequest(kind: .inboxDismiss, payload: .inboxDismiss(messageID: uuid))
        try? IPCDirectory.ensureDirectories()
        try? IPCWriter.enqueue(request)
        IPCWriter.kick()
        return true
    }
}
