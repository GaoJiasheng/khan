import SwiftUI
import KhanUI

/// iOS settings sheet — same sections as the Mac settings panel:
/// Language (UI language), Voice (provider + auto-submit), Appearance
/// (background opacity for the avatar — present here for symmetry even
/// though iOS has no menu-bar avatar; reserved for future floating widget).
///
/// Voice on iOS isn't bound to a global hotkey (no global flagsChanged
/// monitor on iOS), so the trigger-key column doesn't apply — instead the
/// user taps the in-app voice button on the Today tab.
struct SettingsScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var lang = LanguageSettings.shared
    @ObservedObject private var voice = IOSVoiceSettings.shared
    @ObservedObject private var theme = ThemeSettings.shared

    var body: some View {
        NavigationStack {
            ZStack {
                CyberBackground()
                Form {
                    themeSection
                    languageSection
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
                    .foregroundStyle(.white)
            }
        } header: {
            Text(L("Language", "语言"))
                .foregroundStyle(.white.opacity(0.7))
        } footer: {
            Text(L("Switch the UI between English, Chinese, or both side-by-side.",
                   "在英文、中文或双语之间切换界面显示。"))
                .foregroundStyle(.white.opacity(0.5))
        }
        .listRowBackground(Color.black.opacity(0.35))
    }

    private var voiceSection: some View {
        Section {
            Picker(selection: $voice.provider) {
                ForEach(IOSVoiceSettings.Provider.allCases) { p in
                    Text(p.displayName).tag(p)
                }
            } label: {
                Text(L("Send to", "发送给"))
                    .foregroundStyle(.white)
            }
            Picker(selection: $voice.language) {
                ForEach(IOSVoiceSettings.VoiceLanguage.allCases) { l in
                    Text(l.displayName).tag(l)
                }
            } label: {
                Text(L("Language", "识别语言"))
                    .foregroundStyle(.white)
            }
            Toggle(isOn: $voice.copyToClipboard) {
                Text(L("Copy transcript to clipboard",
                       "复制转写文字到剪贴板"))
                    .foregroundStyle(.white)
            }
        } header: {
            Text(L("Voice", "语音"))
                .foregroundStyle(.white.opacity(0.7))
        } footer: {
            Text(L(
                "On iOS, tap the dictate button on the Today tab. Khan transcribes locally with Apple Speech and (depending on the provider) opens the target app or its website with the text.",
                "在 iOS 上,点击「今日」页的口述按钮。Khan 用 Apple Speech 本地转写后,根据所选的目标 App 直接打开或跳转到对应网页。"
            ))
            .foregroundStyle(.white.opacity(0.5))
        }
        .listRowBackground(Color.black.opacity(0.35))
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text(L("Version", "版本"))
                    .foregroundStyle(.white)
                Spacer()
                Text("0.3.0")
                    .foregroundStyle(.white.opacity(0.6))
                    .monospacedDigit()
            }
        } header: {
            Text(L("About", "关于"))
                .foregroundStyle(.white.opacity(0.7))
        }
        .listRowBackground(Color.black.opacity(0.35))
    }
}
