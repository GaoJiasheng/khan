import ArgumentParser
import Foundation

@main
struct Doris: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "doris",
        abstract: "Push notifications, notes, and inbox commands to your doris helper.",
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
