import SwiftUI
import DorisUI

struct DorisCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Note") {
                if let url = URL(string: "doris://new-note") {
                    NSWorkspace.shared.open(url)
                }
            }
            .keyboardShortcut("n")
        }
        CommandGroup(after: .appInfo) {
            Button("Sync Now") {
                if let url = URL(string: "doris://sync") {
                    NSWorkspace.shared.open(url)
                }
            }
            .keyboardShortcut("r", modifiers: [.command, .option])
        }
    }
}
