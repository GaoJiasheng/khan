import ArgumentParser
import Foundation

@main
struct Khan: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "khan",
        abstract: "Push notifications, notes, and inbox commands to your khan helper.",
        version: "0.1.0",
        subcommands: [
            NotifyCommand.self,
            PushCommand.self,
            NoteCommand.self,
            InboxCommand.self,
            DevicesCommand.self,
            AuthCommand.self,
            SyncCommand.self,
            InstallCommand.self
        ]
    )
}
