import AppIntents

struct DorisIntents: AppIntentsPackage {}

struct DorisShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PushNotificationIntent(),
            phrases: ["Push notification with \(.applicationName)"],
            shortTitle: "Push Notification",
            systemImageName: "bell"
        )
        AppShortcut(
            intent: AddNoteIntent(),
            phrases: ["Add note in \(.applicationName)"],
            shortTitle: "Add Note",
            systemImageName: "note.text.badge.plus"
        )
        AppShortcut(
            intent: OpenSidebarIntent(),
            phrases: ["Open \(.applicationName) sidebar"],
            shortTitle: "Open Sidebar",
            systemImageName: "sidebar.right"
        )
    }
}
