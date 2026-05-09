import SwiftUI
import DorisCore
import DorisUI

/// iOS settings sheet — same sections as the Mac settings panel:
/// Theme, Language, Sync, Voice, About.
struct SettingsScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var lang = LanguageSettings.shared
    @ObservedObject private var voice = IOSVoiceSettings.shared
    @ObservedObject private var theme = ThemeSettings.shared
    @ObservedObject private var sync = SyncSettings.shared

    var body: some View {
        NavigationStack {
            ZStack {
                CyberBackground()
                Form {
                    themeSection
                    languageSection
                    syncSection
                    voiceSection
                    aboutSection
                }
                .scrollContentBackground(.hidden)
            }
            .ignoresSafeArea(edges: .top)
            .navigationTitle(L("Settings", "设置"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("Done", "完成")) { dismiss() }
                        .foregroundStyle(CyberPalette.neonCyan)
                }
            }
        }
    }

    private var themeSection: some View {
        Section {
            Picker(selection: $theme.mode) {
                ForEach(ThemeSettings.Mode.allCases) { m in
                    Label(m.displayName, systemImage: m.iconName).tag(m)
                }
            } label: {
                Text(L("Theme", "主题"))
                    .foregroundStyle(.primary)
            }
        } header: {
            Text(L("Appearance", "外观"))
                .foregroundStyle(.primary.opacity(0.7))
        } footer: {
            Text(L("Dark uses the deep purple cyber backdrop. Light uses a softer cream version with the same neon accents.",
                   "深色为标准赛博紫黑底,浅色为柔和奶油底,两种模式都保留同样的霓虹粉青配色。"))
                .foregroundStyle(.primary.opacity(0.5))
        }
        .listRowBackground(Color.primary.opacity(0.05))
    }

    private var languageSection: some View {
        Section {
            Picker(selection: $lang.mode) {
                ForEach(LanguageSettings.Mode.allCases) { m in
                    Text(m.displayName).tag(m)
                }
            } label: {
                Text(L("Display", "显示"))
                    .foregroundStyle(.primary)
            }
        } header: {
            Text(L("Language", "语言"))
                .foregroundStyle(.primary.opacity(0.7))
        } footer: {
            Text(L("Switch the UI between English, Chinese, or both side-by-side.",
                   "在英文、中文或双语之间切换界面显示。"))
                .foregroundStyle(.primary.opacity(0.5))
        }
        .listRowBackground(Color.primary.opacity(0.05))
    }

    /// Sync section — mirrors the Mac Settings → Sync tab. CloudKit
    /// toggle, auto-sync toggle, manual "Sync Now" with last-synced
    /// timestamp updated live.
    private var syncSection: some View {
        Section {
            Toggle(isOn: $sync.cloudKitEnabled) {
                Text(L("Use iCloud sync", "使用 iCloud 同步"))
                    .foregroundStyle(.primary)
            }
            Toggle(isOn: $sync.autoSyncEnabled) {
                Text(L("Auto-sync every minute", "每分钟自动同步"))
                    .foregroundStyle(.primary)
            }
            IOSSyncNowRow()
        } header: {
            Text(L("Sync", "同步"))
                .foregroundStyle(.primary.opacity(0.7))
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if sync.cloudKitEnabled {
                    Text(L("Restart Doris after toggling iCloud for the change to take effect.",
                           "切换 iCloud 后需要重启 Doris 才能生效。"))
                } else {
                    Text(L("Local only. Notes stay on this device.",
                           "仅本地存储,笔记不会离开本机。"))
                }
            }
            .foregroundStyle(.primary.opacity(0.5))
        }
        .listRowBackground(Color.primary.opacity(0.05))
    }

    private var voiceSection: some View {
        Section {
            Picker(selection: $voice.provider) {
                ForEach(IOSVoiceSettings.Provider.allCases) { p in
                    Text(p.displayName).tag(p)
                }
            } label: {
                Text(L("Send to", "发送给"))
                    .foregroundStyle(.primary)
            }
            Picker(selection: $voice.language) {
                ForEach(IOSVoiceSettings.VoiceLanguage.allCases) { l in
                    Text(l.displayName).tag(l)
                }
            } label: {
                Text(L("Language", "识别语言"))
                    .foregroundStyle(.primary)
            }
            Toggle(isOn: $voice.copyToClipboard) {
                Text(L("Copy transcript to clipboard",
                       "复制转写文字到剪贴板"))
                    .foregroundStyle(.primary)
            }
        } header: {
            Text(L("Voice", "语音"))
                .foregroundStyle(.primary.opacity(0.7))
        } footer: {
            Text(L(
                "On iOS, tap the dictate button on the Today tab. Doris transcribes locally with Apple Speech and (depending on the provider) opens the target app or its website with the text.",
                "在 iOS 上,点击「今日」页的口述按钮。Doris 用 Apple Speech 本地转写后,根据所选的目标 App 直接打开或跳转到对应网页。"
            ))
            .foregroundStyle(.primary.opacity(0.5))
        }
        .listRowBackground(Color.primary.opacity(0.05))
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text(L("Version", "版本"))
                    .foregroundStyle(.primary)
                Spacer()
                Text("0.7.0")
                    .foregroundStyle(.primary.opacity(0.6))
                    .monospacedDigit()
            }
        } header: {
            Text(L("About", "关于"))
                .foregroundStyle(.primary.opacity(0.7))
        }
        .listRowBackground(Color.primary.opacity(0.05))
    }
}

/// "Sync Now" row — button + live last-synced timestamp. Mirrors the
/// Mac Settings Sync tab. Wraps in a separate struct so the second-tick
/// timer doesn't churn the parent's body.
private struct IOSSyncNowRow: View {
    @ObservedObject private var sync = SyncSettings.shared
    @State private var isSyncing: Bool = false
    @State private var nowTick: Date = Date()
    private let tickTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack {
            Button {
                tap()
            } label: {
                HStack(spacing: 8) {
                    if isSyncing {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(CyberPalette.neonCyan)
                    }
                    Text(isSyncing
                         ? L("Syncing…", "同步中…")
                         : L("Sync Now", "立即同步"))
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)
            .disabled(isSyncing)
            Spacer()
            Text(lastSyncedLabel)
                .font(.caption)
                .foregroundStyle(.primary.opacity(0.55))
                .monospacedDigit()
        }
        .onReceive(tickTimer) { nowTick = $0 }
    }

    private var lastSyncedLabel: String {
        guard let last = sync.lastSyncedAt else {
            return L("Never synced", "尚未同步")
        }
        _ = nowTick // dependency
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: last, relativeTo: Date())
    }

    private func tap() {
        isSyncing = true
        AppCommands.syncNow()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            isSyncing = false
        }
    }
}
