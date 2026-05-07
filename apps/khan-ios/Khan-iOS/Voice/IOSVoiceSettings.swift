import Foundation
import SwiftUI
import KhanUI

/// iOS voice settings. Simpler than the Mac version because:
///
/// - No global hotkey — iOS doesn't expose a system-wide modifier-key
///   monitor. The user triggers dictation by tapping the in-app button.
/// - No "frontmost app paste" — iOS apps can't synthesize keystrokes into
///   each other. Routing happens via custom URL schemes (chatgpt://) +
///   pasteboard, falling back to opening the provider's website.
@MainActor
final class IOSVoiceSettings: ObservableObject {
    static let shared = IOSVoiceSettings()

    enum Provider: String, CaseIterable, Identifiable {
        case chatGPT
        case claude

        var id: String { rawValue }

        @MainActor
        var displayName: String {
            switch self {
            case .chatGPT: return L("ChatGPT", "ChatGPT")
            case .claude:  return L("Claude",  "Claude")
            }
        }

        /// iOS app's custom URL scheme. Both ChatGPT and Claude support
        /// `<scheme>://?q=` to open with a pre-filled prompt.
        var customURLScheme: String {
            switch self {
            case .chatGPT: return "chatgpt"
            case .claude:  return "claude"
            }
        }

        /// Web fallback — used when the iOS app isn't installed.
        var webURL: URL {
            switch self {
            case .chatGPT: return URL(string: "https://chatgpt.com/")!
            case .claude:  return URL(string: "https://claude.ai/new")!
            }
        }
    }

    enum VoiceLanguage: String, CaseIterable, Identifiable {
        case auto, chinese, english, cantonese

        var id: String { rawValue }

        @MainActor
        var displayName: String {
            switch self {
            case .auto:      return L("Auto",      "自动")
            case .chinese:   return L("Chinese",   "中文")
            case .english:   return L("English",   "英文")
            case .cantonese: return L("Cantonese", "粤语")
            }
        }

        var locale: Locale {
            switch self {
            case .chinese:   return Locale(identifier: "zh-CN")
            case .english:   return Locale(identifier: "en-US")
            case .cantonese: return Locale(identifier: "zh-HK")
            case .auto:
                for tag in Locale.preferredLanguages {
                    let l = Locale(identifier: tag)
                    if l.language.languageCode?.identifier == "zh" {
                        return Locale(identifier: "zh-CN")
                    }
                    if l.language.languageCode?.identifier == "en" {
                        return Locale(identifier: "en-US")
                    }
                }
                return Locale(identifier: "en-US")
            }
        }
    }

    @Published var provider: Provider {
        didSet { UserDefaults.standard.set(provider.rawValue, forKey: "khan.ios.voice.provider") }
    }
    @Published var language: VoiceLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "khan.ios.voice.language") }
    }
    @Published var copyToClipboard: Bool {
        didSet { UserDefaults.standard.set(copyToClipboard, forKey: "khan.ios.voice.copyToClipboard") }
    }

    private init() {
        let d = UserDefaults.standard
        self.provider = (d.string(forKey: "khan.ios.voice.provider").flatMap(Provider.init(rawValue:))) ?? .chatGPT
        self.language = (d.string(forKey: "khan.ios.voice.language").flatMap(VoiceLanguage.init(rawValue:))) ?? .auto
        self.copyToClipboard = (d.object(forKey: "khan.ios.voice.copyToClipboard") as? Bool) ?? true
    }
}
