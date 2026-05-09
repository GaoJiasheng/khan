import SwiftUI
import DorisCore

struct InstallCLIWizardView: View {
    @State private var status: String = "Ready"
    @State private var lastInstalledPath: String?
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Install the `doris` CLI")
                .font(.title2)
            Text("This will symlink the CLI bundled inside Doris.app to /usr/local/bin/doris so you can run `doris notify ...` from any shell.")
                .font(.body)
            Text(status)
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack {
                Button("Install to /usr/local/bin") {
                    install(to: "/usr/local/bin/doris")
                }
                .keyboardShortcut(.defaultAction)
                Button("Install to ~/.local/bin") {
                    let home = ProcessInfo.processInfo.environment["HOME"] ?? "~"
                    install(to: "\(home)/.local/bin/doris")
                }
                Button("Skip") { onClose() }
            }
        }
        .padding(20)
        .frame(width: 480)
    }

    private func install(to destination: String) {
        guard let bundleCLI = Bundle.main.url(forResource: "doris", withExtension: nil) else {
            status = "Could not locate the bundled CLI."
            return
        }
        let dest = (destination as NSString).standardizingPath
        let parent = (dest as NSString).deletingLastPathComponent
        if !FileManager.default.fileExists(atPath: parent) {
            do {
                try FileManager.default.createDirectory(atPath: parent, withIntermediateDirectories: true)
            } catch {
                status = "Could not create \(parent). You may need to run: sudo mkdir -p \(parent)"
                return
            }
        }
        do {
            if FileManager.default.fileExists(atPath: dest) {
                try FileManager.default.removeItem(atPath: dest)
            }
            try FileManager.default.createSymbolicLink(atPath: dest, withDestinationPath: bundleCLI.path)
            status = "Installed to \(dest)"
            lastInstalledPath = dest
        } catch {
            status = "Failed: \(error.localizedDescription). You may need to install manually: ln -s \(bundleCLI.path) \(dest)"
        }
    }
}
