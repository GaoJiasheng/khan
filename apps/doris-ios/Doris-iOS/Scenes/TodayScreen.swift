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
                VStack(alignment: .leading, spacing: 22) {

                    // ── Block 1: Weather ─────────────────────────────────
                    TodayWeatherCard(vm: weather)

                    // ── Block 2: Pinned tasks ─────────────────────────────
                    if !pinnedNotes.isEmpty {
                        sectionHeader(
                            icon: "pin.fill",
                            title: L("Pinned", "置顶"),
                            tint: CyberPalette.neonCyan
                        )
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 10),
                                GridItem(.flexible(), spacing: 10)
                            ],
                            spacing: 10
                        ) {
                            ForEach(pinnedNotes) { n in
                                Button { path.append(n.id) } label: {
                                    PinnedNoteCard(note: n)
                                }
                                .buttonStyle(.plain)
                            }
                        }
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
                .padding(.top, 10)
                .padding(.bottom, 32)
            }
            .scrollContentBackground(.hidden)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) { navTitle }
                ToolbarItem(placement: .topBarTrailing) { ThemeToggleButton() }
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
        VStack(spacing: 2) {
            Text(Date().formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Text("TODAY")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(CyberPalette.neonCyan.opacity(0.85))
                .kerning(3)
        }
    }

    // MARK: - Section header

    private func sectionHeader(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(tint)
            Text(title.uppercased())
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(tint)
                .kerning(2)
            Rectangle()
                .fill(tint.opacity(0.18))
                .frame(height: 0.6)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 42))
                .foregroundStyle(CyberPalette.neonCyan.opacity(0.45))
            Text(L("All clear", "今日清净"))
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.65))
            Text(L("Pin a note or set a due date to see it here.",
                   "置顶笔记或设定截止日期即可出现在这里。"))
                .font(.system(size: 14))
                .foregroundStyle(.primary.opacity(0.45))
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
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    // Theme-aware colors
    private var tempColor: Color      { isDark ? .white : Color(red: 0.08, green: 0.08, blue: 0.18) }
    private var conditionColor: Color { isDark ? .white.opacity(0.68) : Color(red: 0.15, green: 0.15, blue: 0.30).opacity(0.75) }
    private var metaColor: Color      { isDark ? .white.opacity(0.32) : Color(red: 0.2, green: 0.2, blue: 0.35).opacity(0.45) }
    private var statValueColor: Color { isDark ? .white : Color(red: 0.08, green: 0.08, blue: 0.18) }
    private var statLabelColor: Color { isDark ? .white.opacity(0.42) : Color(red: 0.2, green: 0.2, blue: 0.35).opacity(0.5) }
    private var separatorColor: Color { isDark ? .white.opacity(0.07) : Color.black.opacity(0.06) }

    // Card background differs by theme
    private var cardFill: some ShapeStyle {
        if isDark {
            return AnyShapeStyle(LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.04, blue: 0.14).opacity(0.92),
                    Color(red: 0.02, green: 0.06, blue: 0.16).opacity(0.88)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ))
        } else {
            return AnyShapeStyle(LinearGradient(
                colors: [
                    Color(red: 0.94, green: 0.95, blue: 1.00).opacity(0.88),
                    Color(red: 0.88, green: 0.92, blue: 0.98).opacity(0.82)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ))
        }
    }

    private var borderGradient: LinearGradient {
        isDark
            ? LinearGradient(
                colors: [CyberPalette.neonPink.opacity(0.55), CyberPalette.neonCyan.opacity(0.65)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
            : LinearGradient(
                colors: [CyberPalette.neonPink.opacity(0.40), CyberPalette.neonCyan.opacity(0.50)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(cardFill)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(isDark ? 0.3 : 0.5))
                )

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
                .strokeBorder(borderGradient, lineWidth: isDark ? 0.9 : 0.7)
        )
        // Subtle shadow on light mode for depth
        .shadow(
            color: isDark ? .clear : Color(red: 0.55, green: 0.60, blue: 0.85).opacity(0.18),
            radius: 12, x: 0, y: 4
        )
    }

    private func weatherContent(_ s: WeatherSnapshot) -> some View {
        VStack(spacing: 0) {
            // Top: big temp + icon + location
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: s.symbolName)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(iconPrimary(s), isDark ? Color.white.opacity(0.85) : Color(red: 0.3, green: 0.35, blue: 0.5).opacity(0.9))
                            .font(.system(size: 42, weight: .light))
                        Text("\(Int(s.temperatureC.rounded()))°")
                            .font(.system(size: 64, weight: .thin, design: .rounded).monospacedDigit())
                            .foregroundStyle(tempColor)
                    }
                    Text(WeatherCode.text(for: s.weatherCode))
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(conditionColor)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 5) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(CyberPalette.neonCyan.opacity(isDark ? 0.9 : 1.0))
                        Text(s.locationName)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(CyberPalette.neonCyan.opacity(isDark ? 0.9 : 1.0))
                            .lineLimit(1)
                    }
                    Text(Date(), format: .dateTime.hour().minute())
                        .font(.system(size: 13, design: .monospaced).monospacedDigit())
                        .foregroundStyle(metaColor)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 8)

            // Gradient divider
            LinearGradient(
                colors: [CyberPalette.neonPink.opacity(isDark ? 0.45 : 0.35),
                         CyberPalette.neonCyan.opacity(isDark ? 0.45 : 0.35)],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(height: 0.6)
            .padding(.horizontal, 20)

            // Stat row
            HStack(spacing: 0) {
                statCell(
                    icon: "drop.fill",
                    value: "\(Int(s.precipitationProbability.rounded()))%",
                    label: L("Rain", "降水"),
                    tint: RainScale.tint(s.precipitationProbability)
                )
                Rectangle().fill(separatorColor).frame(width: 0.6).padding(.vertical, 6)
                statCell(
                    icon: "wind",
                    value: "\(Int(s.windSpeedKmh.rounded())) km/h",
                    label: WindScale.compass(s.windDirectionDeg),
                    tint: CyberPalette.neonCyan
                )
                Rectangle().fill(separatorColor).frame(width: 0.6).padding(.vertical, 6)
                statCell(
                    icon: "sun.max.trianglebadge.exclamationmark.fill",
                    value: UVScale.label(s.uvIndex),
                    label: L("UV", "紫外线"),
                    tint: UVScale.tint(s.uvIndex)
                )
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
    }

    private func statCell(icon: String, value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(statValueColor)
            Text(label)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(statLabelColor)
        }
        .frame(maxWidth: .infinity)
    }

    private var loadingView: some View {
        HStack(spacing: 10) {
            ProgressView().tint(CyberPalette.neonCyan.opacity(0.6))
            Text(L("Loading weather…", "加载天气中…"))
                .font(.caption.monospaced())
                .foregroundStyle(conditionColor)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }

    private var emptyView: some View {
        Text(L("Weather unavailable", "天气不可用"))
            .font(.caption.monospaced())
            .foregroundStyle(metaColor)
            .padding(32)
            .frame(maxWidth: .infinity)
    }

    private func iconPrimary(_ s: WeatherSnapshot) -> Color {
        switch s.symbolName {
        case "sun.max.fill", "moon.stars.fill", "moon.fill":
            return Color(red: 1.0, green: 0.80, blue: 0.25)
        case "snowflake", "cloud.snow.fill", "cloud.sleet.fill":
            return isDark ? .white : Color(red: 0.6, green: 0.75, blue: 0.95)
        case "cloud.bolt.rain.fill", "cloud.bolt.fill":
            return Color(red: 1.0, green: 0.82, blue: 0.25)
        default:
            return Color(red: 0.0, green: 0.82, blue: 1.0)
        }
    }
}

// MARK: - Block 2: Pinned note card (flat 2-column grid item)

private struct PinnedNoteCard: View {
    let note: Note

    private var dueChipColor: Color {
        guard let d = note.dueDate else { return CyberPalette.neonCyan }
        if d < Date() { return .red }
        if Calendar.current.isDateInToday(d) { return .yellow }
        return CyberPalette.neonCyan
    }

    private var dueLabel: String? {
        guard let d = note.dueDate else { return nil }
        let cal = Calendar.current
        if d < Date() {
            let days = cal.dateComponents([.day], from: d, to: Date()).day ?? 0
            if days == 0 { return L("Today", "今天") }
            return L("\(days)d overdue", "逾期 \(days) 天")
        }
        if cal.isDateInToday(d)    { return L("Today", "今天") }
        if cal.isDateInTomorrow(d) { return L("Tomorrow", "明天") }
        let days = cal.dateComponents([.day], from: Date(), to: d).day ?? 0
        if days < 7 { return d.formatted(.dateTime.weekday(.abbreviated)) }
        return d.formatted(.dateTime.month(.abbreviated).day())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top: icon · title · pin
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: note.isChecklist ? "checklist" : "note.text")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CyberPalette.neonCyan)
                    .frame(width: 16)
                Text(note.title.isEmpty ? L("Untitled", "无标题") : note.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "pin.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(CyberPalette.neonCyan.opacity(0.45))
            }

            Spacer(minLength: 0)

            // Bottom: progress (checklist) · due (dated) · time (plain)
            bottomMeta
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity)
        .frame(height: 92)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.45))
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(CyberPalette.neonCyan.opacity(0.04))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(CyberPalette.neonCyan.opacity(0.22), lineWidth: 0.7)
        )
    }

    @ViewBuilder
    private var bottomMeta: some View {
        if note.isChecklist, let items = note.checklistItems, !items.isEmpty {
            let done = items.filter(\.done).count
            HStack(spacing: 8) {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.08)).frame(height: 3)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [CyberPalette.neonPink, CyberPalette.neonCyan],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .frame(
                                width: g.size.width * (Double(done) / Double(items.count)),
                                height: 3
                            )
                    }
                }
                .frame(height: 3)
                Text("\(done)/\(items.count)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced).monospacedDigit())
                    .foregroundStyle(.primary.opacity(0.55))
            }
        } else if let label = dueLabel {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: 9, weight: .semibold))
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
            }
            .foregroundStyle(dueChipColor)
        } else {
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 9))
                Text(note.updatedAt, style: .relative)
                    .font(.system(size: 11, design: .monospaced))
            }
            .foregroundStyle(.primary.opacity(0.4))
        }
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
            VStack(spacing: 2) {
                Text(due.formatted(.dateTime.day()))
                    .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(chipColor)
                Text(due.formatted(.dateTime.month(.abbreviated)).uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(chipColor.opacity(0.7))
            }
            .frame(width: 46)

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
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(dueLabel)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(chipColor)
                    if note.isChecklist {
                        let items = note.checklistItems ?? []
                        let done = items.filter(\.done).count
                        if !items.isEmpty {
                            Text("· \(done)/\(items.count)")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.primary.opacity(0.4))
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
