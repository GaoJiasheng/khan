import SwiftUI
import SwiftData
import DorisCore
import DorisUI

/// iOS Today tab — three blocks:
///   1. Weather card — full-width ambient weather panel
///   2. Pinned tasks — horizontal scroll carousel
///   3. Calendar — upcoming / overdue notes sorted by dueDate
struct TodayScreen: View {
    @ObservedObject private var lang = LanguageSettings.shared
    @ObservedObject private var weather = WeatherViewModel.shared
    @Environment(\.modelContext) private var ctx

    @Query(
        filter: #Predicate<Note> { note in !note.archived },
        sort: [SortDescriptor(\Note.updatedAt, order: .reverse)]
    )
    private var allNotes: [Note]

    @State private var path = NavigationPath()

    private var pinnedNotes: [Note] {
        allNotes.filter { $0.pinned }
    }

    private var calendarNotes: [Note] {
        allNotes
            .filter { $0.dueDate != nil }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {

                    // ── Block 1: Weather ─────────────────────────────────
                    TodayWeatherCard(vm: weather)

                    // ── Block 2: Pinned tasks ─────────────────────────────
                    if !pinnedNotes.isEmpty {
                        sectionHeader(
                            icon: "pin.fill",
                            title: L("Pinned", "置顶"),
                            tint: CyberPalette.neonCyan
                        )
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(pinnedNotes) { n in
                                    Button { path.append(n.id) } label: {
                                        PinnedNoteCard(note: n)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.horizontal, -16)
                    }

                    // ── Block 3: Calendar ─────────────────────────────────
                    if !calendarNotes.isEmpty {
                        sectionHeader(
                            icon: "calendar",
                            title: L("Upcoming", "日程"),
                            tint: CyberPalette.neonPink
                        )
                        VStack(spacing: 8) {
                            ForEach(calendarNotes) { n in
                                NavigationLink(value: n.id) {
                                    CalendarNoteRow(note: n)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Empty state (no pinned, no calendar)
                    if pinnedNotes.isEmpty && calendarNotes.isEmpty {
                        emptyState
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 36)
            }
            .scrollContentBackground(.hidden)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) { navTitle }
            }
            .navigationDestination(for: UUID.self) { id in
                if let note = allNotes.first(where: { $0.id == id }) {
                    NoteDetailScreen(note: note) {
                        if !path.isEmpty { path.removeLast() }
                    }
                }
            }
            .onAppear { weather.start() }
        }
    }

    // MARK: - Nav title

    private var navTitle: some View {
        VStack(spacing: 1) {
            Text(Date().formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Text("TODAY")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(CyberPalette.neonCyan.opacity(0.8))
                .kerning(2)
        }
    }

    // MARK: - Section header

    private func sectionHeader(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(tint)
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(tint)
                .kerning(1.8)
            Rectangle()
                .fill(tint.opacity(0.18))
                .frame(height: 0.6)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 34))
                .foregroundStyle(CyberPalette.neonCyan.opacity(0.45))
            Text(L("All clear", "今日清净"))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.65))
            Text(L("Pin a note or set a due date to see it here.",
                   "置顶笔记或设定截止日期即可出现在这里。"))
                .font(.caption)
                .foregroundStyle(.primary.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}

// MARK: - Block 1: Weather card

private struct TodayWeatherCard: View {
    @ObservedObject var vm: WeatherViewModel
    @ObservedObject private var lang = LanguageSettings.shared

    var body: some View {
        ZStack {
            cardBackground
            Group {
                if let s = vm.snapshot {
                    weatherContent(s)
                } else if vm.isLoading {
                    loadingView
                } else {
                    emptyView
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            CyberPalette.neonPink.opacity(0.45),
                            CyberPalette.neonCyan.opacity(0.55)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.9
                )
        )
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.ultraThinMaterial.opacity(0.55))
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(
                        colors: [
                            CyberPalette.neonPink.opacity(0.07),
                            Color.clear,
                            CyberPalette.neonCyan.opacity(0.07)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            )
    }

    private func weatherContent(_ s: WeatherSnapshot) -> some View {
        VStack(spacing: 0) {
            // Top: big temp + icon + location
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: s.symbolName)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(iconPrimary(s), Color.white.opacity(0.85))
                            .font(.system(size: 32, weight: .light))
                        Text("\(Int(s.temperatureC.rounded()))°")
                            .font(.system(size: 56, weight: .thin, design: .rounded).monospacedDigit())
                            .foregroundStyle(.white)
                    }
                    Text(WeatherCode.text(for: s.weatherCode))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    HStack(spacing: 3) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(CyberPalette.neonCyan.opacity(0.9))
                        Text(s.locationName)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(CyberPalette.neonCyan.opacity(0.9))
                            .lineLimit(1)
                    }
                    Text(Date(), format: .dateTime.hour().minute())
                        .font(.system(size: 10, design: .monospaced).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.35))
                    if s.isDay {
                        Text(L("Daytime", "白天"))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.3))
                    } else {
                        Text(L("Night", "夜晚"))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 14)

            // Divider
            LinearGradient(
                colors: [
                    CyberPalette.neonPink.opacity(0.4),
                    CyberPalette.neonCyan.opacity(0.4)
                ],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(height: 0.6)
            .padding(.horizontal, 20)

            // Bottom: stat row
            HStack(spacing: 0) {
                statCell(
                    icon: "drop.fill",
                    value: "\(Int(s.precipitationProbability.rounded()))%",
                    label: L("Rain", "降水"),
                    tint: RainScale.tint(s.precipitationProbability)
                )
                separator
                statCell(
                    icon: "wind",
                    value: "\(Int(s.windSpeedKmh.rounded())) km/h",
                    label: WindScale.compass(s.windDirectionDeg),
                    tint: CyberPalette.neonCyan
                )
                separator
                statCell(
                    icon: "sun.max.trianglebadge.exclamationmark.fill",
                    value: UVScale.label(s.uvIndex),
                    label: L("UV", "紫外线"),
                    tint: UVScale.tint(s.uvIndex)
                )
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(width: 0.6)
            .padding(.vertical, 4)
    }

    private func statCell(icon: String, value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
    }

    private var loadingView: some View {
        HStack(spacing: 10) {
            ProgressView().tint(.white.opacity(0.5))
            Text(L("Loading weather…", "加载天气中…"))
                .font(.caption.monospaced())
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }

    private var emptyView: some View {
        Text(L("Weather unavailable", "天气不可用"))
            .font(.caption.monospaced())
            .foregroundStyle(.white.opacity(0.35))
            .padding(32)
            .frame(maxWidth: .infinity)
    }

    private func iconPrimary(_ s: WeatherSnapshot) -> Color {
        switch s.symbolName {
        case "sun.max.fill", "moon.stars.fill", "moon.fill":
            return Color(red: 1.0, green: 0.82, blue: 0.35)
        case "snowflake", "cloud.snow.fill", "cloud.sleet.fill":
            return .white
        case "cloud.bolt.rain.fill", "cloud.bolt.fill":
            return Color(red: 1.0, green: 0.85, blue: 0.30)
        default:
            return Color(red: 0.0, green: 0.85, blue: 1.0)
        }
    }
}

// MARK: - Block 2: Pinned note card (horizontal carousel item)

private struct PinnedNoteCard: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: note.isChecklist ? "checklist" : "note.text")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(CyberPalette.neonCyan)
                Spacer()
                Image(systemName: "pin.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(CyberPalette.neonCyan.opacity(0.5))
            }
            .padding(.bottom, 10)

            // Title
            Text(note.title.isEmpty ? L("Untitled", "无标题") : note.title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 8)

            // Footer
            if note.isChecklist {
                let items = note.checklistItems ?? []
                let done = items.filter(\.done).count
                if !items.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.06)).frame(height: 2.5)
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [CyberPalette.neonPink, CyberPalette.neonCyan],
                                            startPoint: .leading, endPoint: .trailing
                                        )
                                    )
                                    .frame(
                                        width: g.size.width * (Double(done) / Double(items.count)),
                                        height: 2.5
                                    )
                            }
                        }
                        .frame(height: 2.5)
                        Text("\(done) / \(items.count)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.primary.opacity(0.4))
                    }
                }
            } else {
                Text(note.updatedAt, style: .relative)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.3))
            }
        }
        .padding(14)
        .frame(width: 148, height: 136)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.45))
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(CyberPalette.neonCyan.opacity(0.04))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(CyberPalette.neonCyan.opacity(0.22), lineWidth: 0.7)
        )
    }
}

// MARK: - Block 3: Calendar note row

private struct CalendarNoteRow: View {
    let note: Note

    private var due: Date { note.dueDate ?? .distantFuture }

    private var chipColor: Color {
        if due < Date() { return .red }
        if Calendar.current.isDateInToday(due) { return .yellow }
        return CyberPalette.neonCyan
    }

    private var dueLabel: String {
        let cal = Calendar.current
        if due < Date() {
            let days = cal.dateComponents([.day], from: due, to: Date()).day ?? 0
            if days == 0 { return L("Today", "今天") }
            return L("\(days)d overdue", "逾期 \(days) 天")
        }
        if cal.isDateInToday(due)     { return L("Today", "今天") }
        if cal.isDateInTomorrow(due)  { return L("Tomorrow", "明天") }
        let days = cal.dateComponents([.day], from: Date(), to: due).day ?? 0
        if days < 7 { return due.formatted(.dateTime.weekday(.wide)) }
        return due.formatted(.dateTime.month(.abbreviated).day())
    }

    var body: some View {
        HStack(spacing: 14) {
            // Date column
            VStack(spacing: 1) {
                Text(due.formatted(.dateTime.day()))
                    .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(chipColor)
                Text(due.formatted(.dateTime.month(.abbreviated)).uppercased())
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundStyle(chipColor.opacity(0.65))
            }
            .frame(width: 38)

            // Accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: [chipColor.opacity(0.8), chipColor.opacity(0.1)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: 2)
                .padding(.vertical, 4)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(note.title.isEmpty ? L("Untitled", "无标题") : note.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(dueLabel)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(chipColor)
                    if note.isChecklist {
                        let items = note.checklistItems ?? []
                        let done = items.filter(\.done).count
                        if !items.isEmpty {
                            Text("· \(done)/\(items.count)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.primary.opacity(0.35))
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.15))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(chipColor.opacity(0.12), lineWidth: 0.6)
        )
    }
}
