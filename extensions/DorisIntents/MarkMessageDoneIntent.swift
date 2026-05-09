import AppIntents
import Foundation
import DorisIPC

struct MarkMessageDoneIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark Message Done"
    static var description = IntentDescription("Mark a doris inbox message as actioned.")

    @Parameter(title: "Message ID")
    var messageID: String

    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: messageID) else {
            throw NSError(domain: "doris.intents", code: 1, userInfo: [NSLocalizedDescriptionKey: "invalid uuid"])
        }
        let request = IPCRequest(kind: .inboxDone, payload: .inboxDone(messageID: uuid))
        try IPCDirectory.ensureDirectories()
        try IPCWriter.enqueue(request)
        IPCWriter.kick()
        return .result()
    }
}
