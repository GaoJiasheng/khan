import AppKit
import SwiftUI
import DorisUI

/// Stand-alone settings panel. Lives outside the menu-bar avatar so the
/// pickers and bindings table can be a regular floating window the user
/// can click around in.
///
/// Styling: matches the dropdown panel + main window — adaptive cyber
/// gradient (dark / light), no vibrancy, no HUD chrome. The previous
/// `.hudWindow` style mask is what gave the window that frosted-glass /
/// dark translucent look the user complained about.
@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSPanel?

    func show() {
        if let existing = window {
            existing.title = L("Doris · Settings", "Doris · 设置")
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let panel = NSPanel(
            // Compact size — was 660pt tall with a lot of empty bottom
            // space. 560 fits the four sections snugly with breathing
            // room for one more binding row.
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 560),
            // Plain titled panel — no `.hudWindow` (that style mask
            // gave us the dark vibrancy / frosted-glass look).
            // `.fullSizeContentView` lets the SwiftUI content extend
            // under the title bar so our `CyberPalette.backdrop`
            // gradient fills the whole window including the title-bar
            // strip. Without this the titlebar would render as either
            // empty (with `titlebarAppearsTransparent = true`) or as
            // the system's default light-gray vibrancy bar.
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        panel.title = L("Doris · Settings", "Doris · 设置")
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        // Solid window — let the SwiftUI backdrop (`CyberPalette.backdrop`)
        // paint the actual color so it follows Dark / Light theme. The
        // window itself is just a transparent titlebar host.
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.titlebarAppearsTransparent = true
        // Hide the title text but keep the close button — titlebar
        // becomes a translucent strip over the gradient with just the
        // traffic-light buttons. (Title text on the cyber gradient
        // looks awkward; the window is small enough that "this is
        // settings" is implicit.)
        panel.titleVisibility = .hidden

        let rootView = SettingsRoot()
        let host = NSHostingController(rootView: rootView)
        host.view.wantsLayer = true
        // Strip any NSVisualEffectView SwiftUI / AppKit might layer
        // underneath. Defense in depth — the styleMask change should
        // already cover it.
        DispatchQueue.main.async { stripVisualEffects(from: host.view) }
        panel.contentViewController = host
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = panel
    }

    func close() {
        window?.orderOut(nil)
    }
}

/// Recursively hide any `NSVisualEffectView` inside the host's view tree.
/// macOS sometimes inserts these as backing material for hosted SwiftUI
/// content; once hidden the cyber-gradient background paints unimpeded.
private func stripVisualEffects(from view: NSView) {
    for sub in view.subviews {
        if let vfx = sub as? NSVisualEffectView { vfx.isHidden = true }
        else { stripVisualEffects(from: sub) }
    }
}

/// Wrapper that paints the adaptive cyber backdrop behind the actual
/// settings content and applies the theme's color scheme to the whole
/// subtree. Pulled out so it can be re-rendered when theme changes.
private struct SettingsRoot: View {
    @ObservedObject private var theme = ThemeSettings.shared

    var body: some View {
        ZStack(alignment: .top) {
            // Same `CyberPalette.backdrop` the dropdown panel and main
            // window use — adaptive (dark = deep purple, light = cream),
            // honors `preferredColorScheme` further down.
            CyberPalette.backdrop
                .ignoresSafeArea()
            // Pad the top so the traffic-light buttons don't overlap
            // the first section. Title-bar buttons sit ~6pt down from
            // the top and are ~14pt tall, so 22pt clears them with a
            // little breathing room without wasting space.
            AppearanceSettingsView()
                .padding(.top, 22)
        }
        // Explicit frame is required: when SwiftUI is hosted via
        // NSHostingController inside an NSPanel, removing the frame
        // makes the gradient collapse to 0×0 and the ScrollView
        // shrinks to content size — the window ends up showing only
        // the title-bar strip. Match the panel's content rect.
        .frame(width: 540, height: 540)
        .preferredColorScheme(theme.mode.colorScheme)
    }
}

private struct AppearanceSettingsView: View {
    @ObservedObject var settings = AppearanceSettings.shared
    @ObservedObject var voice = VoiceSettings.shared
    @ObservedObject var lang = LanguageSettings.shared
    @ObservedObject var theme = ThemeSettings.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                themeSection
                Divider().overlay(Color.primary.opacity(0.08))
                languageSection
                Divider().overlay(Color.primary.opacity(0.08))
                voiceSection
                Divider().overlay(Color.primary.opacity(0.08))
                appearanceSection
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
        }
        .scrollContentBackground(.hidden)
    }

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Theme", "主题"))
                .font(.headline)
                .foregroundStyle(.primary)
            HStack {
                Text(L("Mode", "模式"))
                    .frame(width: 110, alignment: .leading)
                    .foregroundStyle(.primary)
                Picker("", selection: $theme.mode) {
                    ForEach(ThemeSettings.Mode.allCases) { m in
                        Label(m.displayName, systemImage: m.iconName).tag(m)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: 240, alignment: .leading)
                Spacer()
                ThemeToggleButton()
            }
            Text(L(
                "Dark = deep purple cyber backdrop. Light = soft cream with the same neon accents. Click the sun/moon button anywhere in the app for a one-click flip.",
                "深色为赛博紫黑底,浅色为奶油色,两种都保留霓虹粉青配色。任何位置的太阳/月亮按钮都能一键切换。"
            ))
            .font(.caption)
            .foregroundStyle(.primary.opacity(0.6))
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Language

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Language", "语言"))
                .font(.headline)
                .foregroundStyle(.primary)
            HStack {
                Text(L("Display", "显示"))
                    .frame(width: 110, alignment: .leading)
                    .foregroundStyle(.primary)
                Picker("", selection: $lang.mode) {
                    ForEach(LanguageSettings.Mode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: 240, alignment: .leading)
                Spacer()
            }
            Text(L(
                "Switch the UI between English and Chinese.",
                "在英文和中文之间切换界面显示。"
            ))
            .font(.caption)
            .foregroundStyle(.primary.opacity(0.6))
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Voice

    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L("Voice", "语音"))
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Toggle(isOn: $voice.enabled) {
                    Text(L("Enabled", "启用"))
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                .toggleStyle(.switch)
            }

            VStack(alignment: .leading, spacing: 6) {
                bindingsHeader
                ForEach($voice.bindings) { $binding in
                    BindingRow(binding: $binding) {
                        voice.removeBinding(id: binding.id)
                    }
                    .disabled(!voice.enabled)
                }

                HStack {
                    Button {
                        voice.addBinding()
                    } label: {
                        Label(L("Add binding", "新增绑定"), systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .disabled(!voice.enabled || voice.bindings.count >= VoiceSettings.TriggerKey.allCases.count)
                    Spacer()
                }
                .padding(.top, 4)
            }

            Text(L(
                "Hold a trigger key, speak, release. Doris transcribes locally with Apple Speech, then activates the chosen app and pastes (with optional auto-submit). Press Esc anytime to abort. First use prompts for Microphone, Speech Recognition, Input Monitoring, and Accessibility.",
                "按住触发键说话,松开后 Doris 用 Apple Speech 本地转写,自动前置目标 App 并粘贴(可选自动回车)。任何时候按 Esc 可终止录音。首次使用会逐步请求麦克风、语音识别、输入监听及辅助功能权限。"
            ))
            .font(.caption)
            .foregroundStyle(.primary.opacity(0.6))
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var bindingsHeader: some View {
        HStack(spacing: 8) {
            Text(L("Trigger", "触发键")).frame(width: 110, alignment: .leading)
            Text(L("Language", "语言")).frame(width: 90, alignment: .leading)
            Text(L("Send to", "发送给")).frame(width: 130, alignment: .leading)
            Text(L("Submit", "回车")).frame(width: 50, alignment: .leading)
            Spacer()
        }
        .font(.caption2)
        .foregroundStyle(.primary.opacity(0.5))
        .padding(.bottom, 2)
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Appearance", "外观"))
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(L("Background opacity", "背景不透明度"))
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(Int(settings.backgroundOpacity * 100))%")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.primary.opacity(0.6))
                }
                Slider(value: $settings.backgroundOpacity, in: 0.30 ... 1.0)
            }

            Text(L(
                "On the notch extension (top edge of a notched display) the avatar always renders as solid black so it fuses with the real notch — this slider has no effect there. On every other edge, the avatar background uses this opacity.",
                "在刘海扩展形态(带刘海屏幕的顶部)下,头像始终渲染为纯黑以与真刘海融合,此滑块无效。其它边缘下,头像背景采用该不透明度。"
            ))
            .font(.caption)
            .foregroundStyle(.primary.opacity(0.6))
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// One row in the bindings table.
private struct BindingRow: View {
    @Binding var binding: VoiceBinding
    let onDelete: () -> Void
    @ObservedObject private var lang = LanguageSettings.shared

    var body: some View {
        HStack(spacing: 8) {
            Picker("", selection: $binding.triggerKey) {
                ForEach(VoiceSettings.TriggerKey.allCases) { k in
                    Text(k.displayName).tag(k)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 110)

            Picker("", selection: $binding.language) {
                ForEach(VoiceSettings.VoiceLanguage.allCases) { l in
                    Text(l.displayName).tag(l)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 90)

            Picker("", selection: $binding.provider) {
                ForEach(VoiceSettings.Provider.allCases) { p in
                    Text(p.displayName).tag(p)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 130)

            Toggle("", isOn: $binding.autoSubmit)
                .toggleStyle(.switch)
                .labelsHidden()
                .frame(width: 50, alignment: .leading)

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(Color.red.opacity(0.7))
            }
            .buttonStyle(.borderless)
            .help(L("Remove this binding", "删除此绑定"))
        }
        .padding(.vertical, 2)
    }
}
