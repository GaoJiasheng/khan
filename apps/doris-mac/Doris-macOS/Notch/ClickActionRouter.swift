import AppKit
import DorisIPC
import DorisUI

@MainActor
enum ClickActionRouter {
    static func execute(_ action: ClickAction) {
        switch action {
        case .openURL(let url):
            NSWorkspace.shared.open(url)
        case .openNote(let id):
            if let url = URL(string: "doris://note/\(id.uuidString)") {
                NSWorkspace.shared.open(url)
            }
        case .runIntent(let name):
            if let url = URL(string: "doris://intent/\(name)") {
                NSWorkspace.shared.open(url)
            }
        case .markDone:
            break
        }
    }
}
