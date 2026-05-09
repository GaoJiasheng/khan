import SwiftUI
import SwiftData
import DorisCore
import DorisUI

/// "Today" tab — the iOS equivalent of the Mac expanded panel. A vertically
/// stacked hero column showing:
///
/// - Header: DORIS · cyber helper, with a settings gear button.
/// - Weather bubble (tap to expand condition / rain / wind / UV).
/// - Avatar hero card (cyber girl scene).
/// - Big voice-capture button — opens the recorder sheet, transcribes, and
///   routes to the user's chosen provider via clipboard + URL scheme.
/// - Quick stats: unread inbox count + recent notes count.
struct TodayScreen: View {
    @ObservedObject private var lang = LanguageSettings.shared
    @StateObject private var weather = WeatherViewModel()
    @State private var showSettings = false
    @State private var showVoice = false

    @Query(filter: #Predicate<Message> { $0.stateRaw == "inbox" })
    private var unread: [Message]

    @Query(sort: [SortDescriptor(\Note.updatedAt, order: .reverse)])
    private var notes: [Note]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header
                weatherRow
                AvatarHero()
                    .frame(height: 360)
                voiceButton
                quickStats
            }
            .padding(18)
        }
        .scrollContentBackground(.hidden)
        .onAppear { weather.start() }
        .onDisappear { weather.stop() }
        .sheet(isPresented: $showSettings) {
            SettingsScreen()
        }
        .sheet(isPresented: $showVoice) {
            VoiceCaptureSheet()
                .presentationDetents([.medium])
                .presentationBackground(.clear)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("DORIS")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .kerning(2)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.85, blue: 1.0),
                                 Color(red: 0.6, green: 1.0, blue: 1.0)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
            Text(L("cyber helper", "赛博助手"))
                .font(.caption.monospaced())
                .foregroundStyle(CyberPalette.neonCyan.opacity(0.75))
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(8)
                    .background(Circle().fill(.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
        }
    }

    private var weatherRow: some View {
        HStack {
            WeatherBubble(vm: weather)
            Spacer()
        }
    }

    // MARK: - Voice button

    private var voiceButton: some View {
        Button {
            showVoice = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(CyberPalette.neonPink)
                VStack(alignment: .leading, spacing: 1) {
                    Text(L("Tap to dictate", "点击口述"))
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(L("Speak, then send to ChatGPT or Claude",
                           "录音后发送给 ChatGPT 或 Claude"))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(14)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color.black.opacity(0.55), Color.black.opacity(0.30)],
                    startPoint: .top, endPoint: .bottom
                ))
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(0.4)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(CyberPalette.panelStroke, lineWidth: 0.8)
        )
    }

    // MARK: - Quick stats

    private var quickStats: some View {
        HStack(spacing: 12) {
            statTile(
                count: unread.count,
                label: L("Unread", "未读"),
                tint: CyberPalette.neonCyan,
                icon: "tray.fill"
            )
            statTile(
                count: notes.count,
                label: L("Notes", "笔记"),
                tint: CyberPalette.neonPink,
                icon: "note.text"
            )
        }
    }

    private func statTile(count: Int, label: String, tint: Color, icon: String) -> some View {
        CyberCard {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                Text("\(count)")
                    .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
        }
    }
}
