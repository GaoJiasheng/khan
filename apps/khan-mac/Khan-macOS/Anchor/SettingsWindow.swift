import AppKit
import SwiftUI

/// Stand-alone settings panel. Lives outside the menu-bar avatar so the slider
/// can be a regular floating window the user can click around in.
@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSPanel?

    func show() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 220),
            styleMask: [.titled, .closable, .nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: true
        )
        panel.title = "Khan · Settings"
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.contentViewController = NSHostingController(rootView: AppearanceSettingsView())
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = panel
    }

    func close() {
        window?.orderOut(nil)
    }
}

private struct AppearanceSettingsView: View {
    @ObservedObject var settings = AppearanceSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Appearance")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Background opacity")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(settings.backgroundOpacity * 100))%")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Slider(value: $settings.backgroundOpacity, in: 0.30 ... 1.0)
            }

            Text("On the notch extension (top edge of a notched display) the avatar always renders as solid black so it fuses with the real notch — this slider has no effect there. On every other edge, the avatar background uses this opacity.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(16)
        .frame(width: 360, height: 220, alignment: .topLeading)
    }
}
