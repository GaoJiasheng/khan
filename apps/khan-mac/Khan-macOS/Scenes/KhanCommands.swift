import SwiftUI
import KhanUI

struct KhanCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Note") {
                if let url = URL(string: "khan://new-note") {
                    NSWorkspace.shared.open(url)
                }
            }
            .keyboardShortcut("n")
        }
        CommandGroup(after: .appInfo) {
            Button("Sync Now") {
                if let url = URL(string: "khan://sync") {
                    NSWorkspace.shared.open(url)
                }
            }
            .keyboardShortcut("r", modifiers: [.command, .option])
        }
    }
}
