import ArgumentParser
import Foundation
import DorisIPC

struct InboxCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "inbox",
        abstract: "Inspect or mutate the inbox.",
        subcommands: [List.self, Tail.self, Dismiss.self, Done.self]
    )

    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "ls", abstract: "List recent inbox messages.")
        @Option var source: String?
        @Option(name: .customLong("since-secs")) var sinceSecs: Double?
        @Flag(name: .customLong("unread")) var unread: Bool = false
        @Option var limit: Int?

        func run() async throws {
            let payload = IPCInboxListPayload(
                source: source.flatMap(SourceKind.init(rawValue:)),
                sinceSeconds: sinceSecs,
                unreadOnly: unread,
                limit: limit
            )
            let request = IPCRequest(kind: .inboxList, payload: .inboxList(payload))
            try? IPCDirectory.ensureDirectories()
            do {
                try IPCWriter.enqueue(request)
                IPCWriter.kick()
            } catch {
                dieIO("doris: failed to enqueue request: \(error)")
            }
            print("doris: requested inbox list (response streams via app outbox; reader UI not yet implemented in CLI v0.1)")
        }
    }

    struct Tail: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "tail", abstract: "Stream new messages as they arrive.")
        func run() async throws {
            print("doris: inbox tail — long-running stream not yet implemented in CLI v0.1; use the app inbox view.")
        }
    }

    struct Dismiss: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "dismiss", abstract: "Dismiss a message by id.")
        @Argument var id: String
        func run() async throws {
            guard let uuid = UUID(uuidString: id) else { dieUsage("doris: invalid message id") }
            let request = IPCRequest(kind: .inboxDismiss, payload: .inboxDismiss(messageID: uuid))
            try? IPCDirectory.ensureDirectories()
            try IPCWriter.enqueue(request)
            IPCWriter.kick()
            print("doris: dismiss queued")
        }
    }

    struct Done: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "done", abstract: "Mark a message as actioned.")
        @Argument var id: String
        func run() async throws {
            guard let uuid = UUID(uuidString: id) else { dieUsage("doris: invalid message id") }
            let request = IPCRequest(kind: .inboxDone, payload: .inboxDone(messageID: uuid))
            try? IPCDirectory.ensureDirectories()
            try IPCWriter.enqueue(request)
            IPCWriter.kick()
            print("doris: done queued")
        }
    }
}
