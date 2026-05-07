import AppKit
import SwiftUI
import KhanUI

/// Stand-alone settings panel. Lives outside the menu-bar avatar so the
/// pickers and bindings table can be a regular floating window the user
/// can click around in.
@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSPanel?

    func show() {
        if let existing = window {
            existing.title = L("Khan · Settings", "Khan · 设置")
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 600),
            styleMask: [.titled, .closable, .nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: true
        )
        panel.title = L("Khan · Settings", "Khan · 设置")
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
    @ObservedObject var voice = VoiceSettings.shared
    @ObservedObject var lang = LanguageSettings.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                languageSection
                Divider()
                voiceSection
                Divider()
                appearanceSection
            }
            .padding(18)
        }
        .frame(width: 540, height: 600)
    }

    // MARK: - Language

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Language", "语言"))
                .font(.headline)
            HStack {
                Text(L("Display", "显示"))
                    .frame(width: 110, alignment: .leading)
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
                "Switch the UI between English, Chinese, or both side-by-side.",
                "在英文、中文或双语之间切换界面显示。"
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Voice

    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L("Voice", "语音"))
                    .font(.headline)
                Spacer()
                Toggle(isOn: $voice.enabled) {
                    Text(L("Enabled", "启用"))
                        .font(.subheadline)
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
                "Hold a trigger key, speak, release. Khan transcribes locally with Apple Speech, then activates the chosen app and pastes (with optional auto-submit). First use prompts for Microphone, Speech Recognition, Input Monitoring, and Accessibility.",
                "按住触发键说话,松开后 Khan 用 Apple Speech 本地转写,自动前置目标 App 并粘贴(可选自动回车)。首次使用会逐步请求麦克风、语音识别、输入监听及辅助功能权限。"
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
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
        .foregroundStyle(.secondary)
        .padding(.bottom, 2)
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Appearance", "外观"))
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(L("Background opacity", "背景不透明度"))
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(settings.backgroundOpacity * 100))%")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Slider(value: $settings.backgroundOpacity, in: 0.30 ... 1.0)
            }

            Text(L(
                "On the notch extension (top edge of a notched display) the avatar always renders as solid black so it fuses with the real notch — this slider has no effect there. On every other edge, the avatar background uses this opacity.",
                "在刘海扩展形态(带刘海屏幕的顶部)下,头像始终渲染为纯黑以与真刘海融合,此滑块无效。其它边缘下,头像背景采用该不透明度。"
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
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
