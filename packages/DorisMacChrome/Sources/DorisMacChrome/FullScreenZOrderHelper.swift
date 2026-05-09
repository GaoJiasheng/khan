import AppKit

@MainActor
public enum FullScreenZOrderHelper {
    public static func applyFixMode(to panel: NSPanel) {
        panel.level = .statusBar - 1
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
    }

    public static func applyNormalMode(to panel: NSPanel) {
        panel.level = .floating
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = true
    }
}
