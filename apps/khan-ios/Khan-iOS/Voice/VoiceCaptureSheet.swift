import SwiftUI
import UIKit
import KhanUI

/// Half-sheet voice capture UI. The user taps & holds the big mic button to
/// record; live partial transcript appears above. On release we route the
/// final text to the configured provider via custom URL scheme + pasteboard,
/// falling back to the provider's website if the iOS app isn't installed.
struct VoiceCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var lang = LanguageSettings.shared
    @ObservedObject private var settings = IOSVoiceSettings.shared

    @State private var phase: Phase = .idle
    @State private var partial: String = ""
    @State private var pulse = false
    @State private var recognizer: IOSSpeechRecognizer?

    enum Phase { case idle, listening, sending, done, error(String) }

    var body: some View {
        ZStack {
            CyberBackground()
            VStack(spacing: 18) {
                handle
                header
                transcriptCard
                Spacer()
                micButton
                statusLabel
                Spacer().frame(height: 20)
            }
            .padding(20)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    // MARK: - Subviews

    private var handle: some View {
        Capsule()
            .fill(Color.white.opacity(0.25))
            .frame(width: 36, height: 4)
            .padding(.top, 6)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(L("Dictate", "口述"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text("→ \(settings.provider.displayName)")
                .font(.caption.monospaced())
                .foregroundStyle(CyberPalette.neonPink.opacity(0.8))
            Spacer()
            Button(L("Cancel", "取消")) { dismiss() }
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private var transcriptCard: some View {
        CyberCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(transcriptHeader)
                    .font(.caption.monospaced())
                    .foregroundStyle(CyberPalette.neonCyan.opacity(0.75))
                Text(partial.isEmpty ? L("Hold the mic and speak.",
                                          "按住麦克风说话。") : partial)
                    .font(.body)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
    }

    private var transcriptHeader: String {
        switch phase {
        case .idle:           return L("Idle", "空闲")
        case .listening:      return L("Listening…", "正在聆听…")
        case .sending:        return L("Sending…", "发送中…")
        case .done:           return L("Sent ✓", "已发送 ✓")
        case .error(let m):   return "Error · \(m)"
        }
    }

    private var micButton: some View {
        Image(systemName: phase == .listening ? "waveform.circle.fill" : "mic.circle.fill")
            .font(.system(size: 88, weight: .medium))
            .foregroundStyle(
                phase == .listening
                    ? CyberPalette.neonPink
                    : CyberPalette.neonCyan
            )
            .scaleEffect(phase == .listening && pulse ? 1.06 : 1.0)
            .shadow(color: (phase == .listening ? CyberPalette.neonPink : CyberPalette.neonCyan).opacity(0.6), radius: 18)
            .gesture(
                LongPressGesture(minimumDuration: 0.15)
                    .onEnded { _ in begin() }
                    .sequenced(before: DragGesture(minimumDistance: 0))
                    .onEnded { _ in Task { await end() } }
            )
            .accessibilityLabel(L("Hold to dictate", "按住口述"))
    }

    private var statusLabel: some View {
        Text(L("Press and hold to record. Release to send.",
               "按住开始录音,松开发送。"))
            .font(.caption)
            .foregroundStyle(.white.opacity(0.5))
    }

    // MARK: - Recording lifecycle

    private func begin() {
        guard recognizer == nil else { return }
        Task { @MainActor in
            // Ensure permissions on first use. If denied we surface a
            // reusable error message rather than starting the recorder.
            let auth = IOSSpeechRecognizer.currentAuthorization()
            if auth != .granted {
                _ = await IOSSpeechRecognizer.requestAuthorization()
                let after = IOSSpeechRecognizer.currentAuthorization()
                if after != .granted {
                    phase = .error(L("Permissions denied", "权限被拒绝"))
                    return
                }
            }

            let r = IOSSpeechRecognizer(locale: settings.language.locale)
            r.onPartial = { [weak r] text in
                _ = r
                partial = text
            }
            do {
                try r.start()
                recognizer = r
                phase = .listening
                partial = ""
            } catch {
                phase = .error(error.localizedDescription)
            }
        }
    }

    private func end() async {
        guard let r = recognizer else { return }
        recognizer = nil
        let result = await r.stop()
        guard !result.text.isEmpty else {
            phase = .idle
            return
        }
        partial = result.text
        phase = .sending
        await routeToProvider(text: result.text)
    }

    /// Routes the transcript to the user's chosen provider:
    /// 1. Copies to UIPasteboard (so user can paste anywhere if URL scheme
    ///    fails or the target app ignores `?q=`).
    /// 2. Tries the provider's custom URL scheme (`chatgpt://` / `claude://`)
    ///    with the text in `?q=`. If the URL can't be opened (app missing
    ///    or scheme not registered), falls back to opening the provider's
    ///    website (https://chatgpt.com / https://claude.ai/new) with `?q=`.
    /// 3. Dismisses the sheet after a brief "sent" pause.
    private func routeToProvider(text: String) async {
        if settings.copyToClipboard {
            UIPasteboard.general.string = text
        }

        var components = URLComponents()
        components.scheme = settings.provider.customURLScheme
        components.host = ""
        components.queryItems = [URLQueryItem(name: "q", value: text)]
        let appURL = components.url

        var opened = false
        if let appURL, await UIApplication.shared.canOpenURL(appURL) {
            opened = await UIApplication.shared.open(appURL)
        }
        if !opened {
            var web = URLComponents(url: settings.provider.webURL, resolvingAgainstBaseURL: false)!
            web.queryItems = [URLQueryItem(name: "q", value: text)]
            if let url = web.url {
                _ = await UIApplication.shared.open(url)
            }
        }

        phase = .done
        try? await Task.sleep(nanoseconds: 600_000_000)
        dismiss()
    }
}
