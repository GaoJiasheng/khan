import AppIntents
import KhanIPC

struct AddNoteIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Note"
    static var description = IntentDescription("Create a new note in khan.")

    @Parameter(title: "Title")
    var title: String

    @Parameter(title: "Body")
    var body: String?

    @Parameter(title: "Folder")
    var folder: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Add note \(\.$title)")
    }

    func perform() async throws -> some IntentResult {
        let payload = IPCNoteAddPayload(title: title, body: body ?? "", folderName: folder)
        let request = IPCRequest(kind: .noteAdd, payload: .noteAdd(payload))
        try IPCDirectory.ensureDirectories()
        try IPCWriter.enqueue(request)
        IPCWriter.kick()
        return .result()
    }
}
