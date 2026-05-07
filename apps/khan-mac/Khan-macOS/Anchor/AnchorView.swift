import SwiftUI
import SwiftData
import KhanCore
import KhanIPC
import KhanMacChrome
import KhanUI

struct AnchorView: View {
    @ObservedObject var model: AnchorModel
    let position: AnchorPosition
    let onTapIdle: () -> Void
    let onTapMessage: (AnchorMessage) -> Void
    let onDismissMessage: (AnchorMessage) -> Void
    let onCloseExpanded: () -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: (CGSize) -> Void

    var body: some View {
        ZStack {
            switch model.state {
            case .idle:
                idleView
            case .banner(let m):
                expandedMessageView(m)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.85, anchor: .top)),
                        removal: .opacity.combined(with: .scale(scale: 0.9, anchor: .top))
                    ))
            case .fix(let m):
                expandedMessageView(m)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.85, anchor: .top)),
                        removal: .opacity.combined(with: .scale(scale: 0.9, anchor: .top))
                    ))
            case .expanded:
                expandedSummaryView
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.85, anchor: .top)),
                        removal: .opacity.combined(with: .scale(scale: 0.9, anchor: .top))
                    ))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: model.state)
        .gesture(
            DragGesture(minimumDistance: 6)
                .onChanged { v in onDragChanged(v.translation) }
                .onEnded { v in onDragEnded(v.translation) }
        )
    }

    private var rendersAsFakeNotch: Bool {
        AnchorPanelLayout.rendersAsFakeNotch(position: position)
    }

    // MARK: - Idle

    @ViewBuilder
    private var idleView: some View {
        if rendersAsFakeNotch {
            fakeNotchIdle
        } else {
            circleIdle
        }
    }

    private var circleIdle: some View {
        Button {
            model.flashClickReaction()
            onTapIdle()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.88))
                    .overlay(Circle().stroke(.white.opacity(0.08), lineWidth: 0.5))
                AnchorAvatarView(state: model.avatarState, size: 18)
            }
            .frame(width: AnchorPanelLayout.circleIdleSize, height: AnchorPanelLayout.circleIdleSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleEffect(model.hovered ? 1.08 : 1.0)
        .animation(.easeInOut(duration: 0.12), value: model.hovered)
        .onHover { model.hovered = $0 }
        .help("Khan")
    }

    private var fakeNotchIdle: some View {
        Button {
            model.flashClickReaction()
            onTapIdle()
        } label: {
            ZStack {
                FakeNotchShape()
                    .fill(Color.black)
                AnchorAvatarView(state: model.avatarState, size: 16)
                    .padding(.bottom, 4)
            }
            .frame(width: AnchorPanelLayout.pillIdleWidth, height: AnchorPanelLayout.pillIdleHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { model.hovered = $0 }
        .help("Khan")
    }

    // MARK: - Expanded message (banner / fix)

    private func expandedMessageView(_ m: AnchorMessage) -> some View {
        let useFakeNotch = rendersAsFakeNotch
        return HStack(alignment: .center, spacing: 12) {
            AnchorAvatarView(state: model.avatarState, size: 28)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(m.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let body = m.body, !body.isEmpty {
                    Text(body)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            Button {
                onDismissMessage(m)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.top, useFakeNotch ? 10 : 14)
        .padding(.bottom, 14)
        .frame(
            width: m.displayMode == .fix ? AnchorPanelLayout.fixWidth : AnchorPanelLayout.bannerWidth,
            height: m.displayMode == .fix ? AnchorPanelLayout.fixHeight : AnchorPanelLayout.bannerHeight,
            alignment: .top
        )
        .background(backgroundShape(useFakeNotch: useFakeNotch))
        .contentShape(Rectangle())
        .onTapGesture { onTapMessage(m) }
    }

    // MARK: - Expanded summary (click → big panel with inbox + notes)

    private var expandedSummaryView: some View {
        let useFakeNotch = rendersAsFakeNotch
        return VStack(spacing: 0) {
            // Header bar
            HStack {
                AnchorAvatarView(state: model.avatarState, size: 22)
                    .frame(width: 26, height: 26)
                Text("Khan").font(.headline).foregroundStyle(.white)
                Spacer()
                Button {
                    onCloseExpanded()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 16)
            .padding(.top, useFakeNotch ? 10 : 14)
            .padding(.bottom, 8)

            Divider().background(.white.opacity(0.15))

            // Tabs
            HStack(spacing: 0) {
                tabButton("Inbox", tag: .inbox)
                tabButton("Notes", tag: .notes)
                tabButton("Today", tag: .today)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider().background(.white.opacity(0.1))

            // Body
            Group {
                switch model.expandedTab {
                case .inbox: AnchorInboxView()
                case .notes: AnchorNotesView()
                case .today: AnchorTodayView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: AnchorController.expandedWidth, height: AnchorController.expandedHeight, alignment: .top)
        .background(backgroundShape(useFakeNotch: useFakeNotch))
        .colorScheme(.dark)
    }

    private func tabButton(_ label: String, tag: AnchorModel.Tab) -> some View {
        Button {
            model.expandedTab = tag
        } label: {
            Text(label)
                .font(.subheadline.weight(model.expandedTab == tag ? .semibold : .regular))
                .foregroundStyle(model.expandedTab == tag ? .white : .white.opacity(0.5))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(model.expandedTab == tag ? Color.white.opacity(0.12) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func backgroundShape(useFakeNotch: Bool) -> some View {
        if useFakeNotch {
            FakeNotchShape(cornerRadius: 22).fill(Color.black)
        } else {
            RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.black)
        }
    }
}

// MARK: - Anchor body subviews

private struct AnchorInboxView: View {
    @Query(sort: [SortDescriptor(\Message.receivedAt, order: .reverse)])
    private var messages: [Message]

    var body: some View {
        let active = messages.filter { $0.state == .inbox }
        if active.isEmpty {
            empty("No new messages", systemImage: "tray")
        } else {
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(active) { m in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: m.iconName ?? m.source.sfSymbol)
                                .foregroundStyle(.white)
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(m.title)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                if let body = m.bodyMarkdown, !body.isEmpty {
                                    Text(body)
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.6))
                                        .lineLimit(2)
                                }
                            }
                            Spacer(minLength: 0)
                            Text(m.receivedAt, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.white.opacity(0.04))
                        )
                    }
                }
                .padding(8)
            }
        }
    }
}

private struct AnchorNotesView: View {
    @Query(sort: [SortDescriptor(\Note.updatedAt, order: .reverse)])
    private var notes: [Note]
    @Environment(\.modelContext) private var ctx

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    let n = Note(title: "New note")
                    ctx.insert(n)
                } label: {
                    Label("New", systemImage: "plus")
                        .font(.caption)
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 12)
                .padding(.top, 6)
            }
            if notes.isEmpty {
                empty("No notes yet", systemImage: "note.text")
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(notes.prefix(20)) { n in
                            HStack {
                                Text(n.title.isEmpty ? "Untitled" : n.title)
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Spacer()
                                Text(n.updatedAt, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.04)))
                        }
                    }
                    .padding(8)
                }
            }
        }
    }
}

private struct AnchorTodayView: View {
    var body: some View {
        empty("Today", systemImage: "sun.max", subtitle: "Recent captures and quick links will live here.")
    }
}

@ViewBuilder
private func empty(_ title: String, systemImage: String, subtitle: String? = nil) -> some View {
    VStack(spacing: 6) {
        Spacer()
        Image(systemName: systemImage)
            .font(.system(size: 28))
            .foregroundStyle(.white.opacity(0.4))
        Text(title)
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.6))
        if let subtitle {
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.35))
                .multilineTextAlignment(.center)
        }
        Spacer()
    }
    .frame(maxWidth: .infinity)
}

// MARK: - Model

@MainActor
final class AnchorModel: ObservableObject {
    enum Tab { case inbox, notes, today }
    @Published var state: AnchorState = .idle
    @Published var hovered: Bool = false
    @Published var expandedTab: Tab = .inbox
    @Published var avatarState: AvatarState = .idle

    private var resetTask: Task<Void, Never>?

    /// Briefly flash the click reaction, then reset to a state appropriate for the
    /// current panel state (idle pill / expanded panel).
    func flashClickReaction() {
        avatarState = .click
        scheduleReset(after: 0.6)
    }

    func flashNotifyReaction() {
        avatarState = .notify
        scheduleReset(after: 0.8)
    }

    private func scheduleReset(after seconds: Double) {
        resetTask?.cancel()
        resetTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            switch self?.state {
            case .expanded: self?.avatarState = .expanded
            default: self?.avatarState = .idle
            }
        }
    }
}

/// Rectangle with rounded BOTTOM corners only — looks like a notch hanging
/// from the top edge of the screen.
struct FakeNotchShape: Shape {
    var cornerRadius: CGFloat = 12

    func path(in rect: CGRect) -> Path {
        let r = min(cornerRadius, min(rect.width, rect.height) / 2)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX - r, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - r),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        p.closeSubpath()
        return p
    }
}
