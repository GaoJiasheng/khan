import AppIntents
import Foundation
import DorisIPC

struct MarkMessageDoneIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark Event Done"
    static var description = IntentDescription("Mark a doris event as actioned.")

    @Parameter(title: "Event ID")
    var messageID: String

    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: messageID) else {
            throw NSError(domain: "doris.intents", code: 1, userInfo: [NSLocalizedDescriptionKey: "invalid uuid"])
        }
        let request = IPCRequest(kind: .eventsDone, payload: .eventsDone(messageID: uuid))
        try IPCDirectory.ensureDirectories()
        try IPCWriter.enqueue(request)
        IPCWriter.kick()
        return .result()
    }
}
