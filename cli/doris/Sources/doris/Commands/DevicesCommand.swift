import ArgumentParser
import Foundation
import DorisIPC

struct DevicesCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "devices",
        abstract: "List devices visible to doris.",
        subcommands: [List.self]
    )

    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "ls", abstract: "List devices.")
        func run() async throws {
            print("doris: device listing not yet implemented in CLI v0.1; use the app's Settings → Devices page.")
        }
    }
}
