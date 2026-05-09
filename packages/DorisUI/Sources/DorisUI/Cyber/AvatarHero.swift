import SwiftUI
import Combine
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// What the avatar is currently doing. Each case maps to a bundled video
/// clip (frames live at `Bundle.module/HeroAnim/<clip>/`):
///
/// - **Loop clips**: idle, listening, walking, sleeping — cycle forever.
/// - **One-shot clips**: greeting, alerted, celebrating, confused — play
///   once, then automatically revert to the underlying loop mood.
public enum HeroMood: Equatable {
    case idle
    case greeting
    case alerted
    case listening
    case celebrating
    case sleeping
    case walking
    case confused

    /// Bundled clip directory name, e.g. `"idle"` → frames at
    /// `HeroAnim/idle/idle_0001.png ... idle_0065.png`. We currently
    /// don't have a `sleeping` clip — fall back to `walking` for now (or
    /// idle) so the player has something to render.
    var clipName: String {
        switch self {
        case .idle:        return "idle"
        case .greeting:    return "greeting"
        case .alerted:     return "alerted"
        case .listening:   return "listening"
        case .celebrating: return "celebrating"
        case .walking:     return "walking"
        case .confused:    return "confused"
        case .sleeping:    return "idle"     // no dedicated clip yet
        }
    }

    var isLooping: Bool {
        switch self {
        case .idle, .listening, .walking, .sleeping: return true
        case .greeting, .alerted, .celebrating, .confused: return false
        }
    }
}

/// Cross-platform cyber-girl hero card. The character is now an animated
/// PNG-frame clip (16 fps, 65 frames each) — replaces the static image
/// that used to be transformed via SwiftUI scaleEffect/rotation. Mood
/// changes swap clips. Environment effects (cyan halo intensity, opacity
/// for sleep, particle bursts, day/night halo, scanlines) still layer on
/// top — they read as ambient feedback rather than character motion.
public struct AvatarHero: View {
    var mood: HeroMood
    var compact: Bool
    var showWeather: Bool
    /// True (default) clips + strokes the standard rounded chrome. Set
    /// false when the parent applies its own clip (e.g. expanded panel
    /// uses an uneven-rounded clip on the left column).
    var selfChrome: Bool

    public init(
        mood: HeroMood = .idle,
        compact: Bool = false,
        showWeather: Bool = false,
        selfChrome: Bool = true
    ) {
        self.mood = mood
        self.compact = compact
        self.showWeather = showWeather
        self.selfChrome = selfChrome
    }

    @StateObject private var weather = WeatherViewModel()
    @ObservedObject private var heroEvents = HeroEvents.shared
    /// Procedural starfield. Generated once on view init so positions stay
    /// stable across renders — only the per-star brightness twinkles.
    @State private var stars: [HeroStar] = (0..<140).map { _ in HeroStar.random() }
    /// Cursor position in the card's local coordinate space, or nil when
    /// the cursor isn't over the card. Drives the cursor halo + nearby-
    /// star boost. Mac-only; iOS doesn't have hover.
    @State private var cursorPos: CGPoint? = nil
    /// Active click ripples — each is a circle that expands and fades
    /// over ~1.2s starting from its `origin`.
    @State private var ripples: [Ripple] = []
    /// Recent click timestamps used to detect a "rapid poke" — three
    /// clicks within 0.6s fires the `confused` reaction instead of a
    /// greeting (the "stop poking me" easter egg).
    @State private var recentClicks: [Date] = []

    // MARK: - State

    /// What's actually playing right now. Distinct from `mood` (the param
    /// telling us the underlying loop) because one-shot reactions drive
    /// `playingMood` temporarily, then revert.
    @State private var playingMood: HeroMood = .idle
    /// One-shot hold — set to .greeting/.alerted/.celebrating/.confused
    /// when an event fires; cleared when the clip finishes playing.
    @State private var pendingOneShot: HeroMood?

    // Environment effect state
    @State private var moodOpacity: Double = 1.0
    @State private var scanlineOffset: CGFloat = 0
    @State private var particles: [HeroParticle] = []
    @State private var autoSleeping: Bool = false

    // MARK: - Body

    public var body: some View {
        // Only the canvas-based ambient layers (twinkling stars, particles,
        // ripples) live inside `TimelineView` — they're the parts that
        // need per-frame redraws. Everything else (the character clip,
        // scanlines, corner brackets, weather pill) is OUTSIDE the
        // timeline so SwiftUI doesn't re-layout the whole tree at frame
        // rate. The character has its own internal 16fps `TimelineView`,
        // so it animates independently without dragging this body with it.
        //
        // Rate dropped from 30fps → 12fps. Twinkle is a slow sin, ripples
        // and particles are forgiving — 12fps looks identical to the eye
        // and cuts CPU enormously (was sitting at 60–80 % during launch
        // with the old 30fps full-tree re-eval).
        ZStack {
            deepSpaceBackdrop      // static gradient, no re-render
            cursorHalo             // re-renders only on cursor move (Mac)
            animatedAmbientLayers  // 12fps Canvas layer for stars/particles/ripples
            scanlines              // CoreAnimation-driven offset, cheap
            character              // owns its own 16fps player TimelineView
            cornerAccents          // static
            if showWeather { weatherOverlay }
        }
        .opacity(moodOpacity)
        .modifier(SelfChromeModifier(enabled: selfChrome, compact: compact))
        .contentShape(Rectangle())
        .onTapGesture(coordinateSpace: .local) { point in
            handleClick(at: point)
        }
        #if os(macOS)
        .onContinuousHover { phase in
            switch phase {
            case .active(let p): cursorPos = p
            case .ended:         cursorPos = nil
            }
        }
        #endif
        .onAppear {
            playingMood = mood
            startPerpetualLoops()
            scheduleAutoSleep()
            if showWeather { weather.start() }
        }
        .onDisappear {
            if showWeather { weather.stop() }
        }
        .onChange(of: mood) { _, new in handleMoodChange(new) }
        .onChange(of: heroEvents.lastCelebration) { _, _ in fireOneShot(.celebrating) }
        .onChange(of: heroEvents.lastGreeting)    { _, _ in fireOneShot(.greeting) }
        .onChange(of: heroEvents.lastAlert)       { _, _ in fireOneShot(.alerted) }
        .onChange(of: heroEvents.isListening)     { _, on in setListening(on) }
    }

    /// The three Canvas-backed ambient layers stacked into one
    /// `TimelineView` so they share a single per-frame tick. Putting them
    /// here (instead of around the whole `body`) keeps the layout engine
    /// from churning the static parts of the hero card — character
    /// clip, weather pill, brackets, etc. — at frame rate.
    ///
    /// **Only the per-frame canvases live inside the timeline.** The
    /// background gradient and cursor halo are layered outside in
    /// `body` because they don't depend on `now`. If they were inside
    /// the closure SwiftUI would re-evaluate them 12 times a second
    /// even though their content hasn't changed.
    private var animatedAmbientLayers: some View {
        // 30 fps for smooth twinkle, particle drift, and ripple expansion.
        // `.periodic` (instead of the original `.animation`) uses a plain
        // dispatch timer rather than binding to the display link, so the
        // SwiftUI `AnimatorState` doesn't tick at 60–120 Hz when we only
        // need 30. Same visual quality, structurally cheaper.
        TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { context in
            ZStack {
                starfield(now: context.date)
                particleLayer(now: context.date)
                rippleLayer(now: context.date)
            }
        }
    }

    /// Static deep-space gradient — never changes, never re-renders. Lives
    /// outside the timeline so the layout engine doesn't touch it on
    /// every tick.
    private var deepSpaceBackdrop: some View {
        LinearGradient(
            colors: [
                Color(red: 0.04, green: 0.04, blue: 0.10),
                Color(red: 0.01, green: 0.01, blue: 0.04)
            ],
            startPoint: .top, endPoint: .bottom
        )
    }

    // MARK: - Layers

    // (Deep-space gradient + cursor halo were extracted out of the
    //  per-frame TimelineView path — see `deepSpaceBackdrop` and
    //  `cursorHalo` layered directly in `body`. Only `starfield(now:)`
    //  stays inside the timeline because that's the layer that actually
    //  needs `now` to drive its twinkle.)

    /// Soft cyan halo following the cursor. Faint enough not to wash out
    /// the stars; just a subtle "your attention is here" cue.
    @ViewBuilder
    private var cursorHalo: some View {
        if let c = cursorPos {
            Circle()
                .fill(RadialGradient(
                    colors: [
                        CyberPalette.neonCyan.opacity(0.18),
                        CyberPalette.neonCyan.opacity(0.05),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0, endRadius: 70
                ))
                .frame(width: 160, height: 160)
                .blur(radius: 6)
                .position(c)
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
                .transition(.opacity)
        }
    }

    /// Renders the star list with per-frame brightness driven by sin
    /// waves. Stars within `cursorBoostRadius` of the cursor twinkle at
    /// 1.6x brightness and 1.5x size.
    private func starfield(now: Date) -> some View {
        Canvas { context, size in
            let t = now.timeIntervalSinceReferenceDate
            let cursor = cursorPos
            let boostRadius: CGFloat = 90

            for star in stars {
                let twinkle = 0.5 + 0.5 * sin(t * star.twinkleSpeed + star.twinklePhase)
                let pos = CGPoint(x: star.x * size.width, y: star.y * size.height)

                // Boost factor — falls off smoothly with distance.
                var boost: Double = 0
                if let c = cursor {
                    let dx = pos.x - c.x
                    let dy = pos.y - c.y
                    let d = sqrt(dx * dx + dy * dy)
                    if d < boostRadius {
                        boost = 1.0 - (d / boostRadius)
                    }
                }

                let opacity = min(1.0, star.baseOpacity * twinkle * (1.0 + boost * 0.6))
                let drawSize = star.size * CGFloat(1.0 + boost * 0.5)

                if drawSize > 1.7 {
                    let glow = CGRect(
                        x: pos.x - drawSize * 1.4,
                        y: pos.y - drawSize * 1.4,
                        width: drawSize * 2.8,
                        height: drawSize * 2.8
                    )
                    context.fill(Path(ellipseIn: glow),
                                 with: .color(star.color.opacity(opacity * 0.30)))
                }
                let rect = CGRect(
                    x: pos.x - drawSize / 2,
                    y: pos.y - drawSize / 2,
                    width: drawSize,
                    height: drawSize
                )
                context.fill(Path(ellipseIn: rect),
                             with: .color(star.color.opacity(opacity)))
            }
        }
        .allowsHitTesting(false)
    }

    /// Click ripples — expanding cyan rings centered on the click point.
    /// One ring per click; lifetime ~1.2s.
    private func rippleLayer(now: Date) -> some View {
        Canvas { context, _ in
            var alive: [Ripple] = []
            for ripple in ripples {
                let elapsed = now.timeIntervalSince(ripple.bornAt)
                guard elapsed < ripple.lifetime else { continue }
                let t = elapsed / ripple.lifetime
                let radius = 6 + 90 * t
                let opacity = max(0, 0.65 * (1.0 - t))
                let rect = CGRect(
                    x: ripple.origin.x - radius,
                    y: ripple.origin.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                context.stroke(
                    Path(ellipseIn: rect),
                    with: .color(CyberPalette.neonCyan.opacity(opacity)),
                    lineWidth: 1.4
                )
                alive.append(ripple)
            }
            if alive.count != ripples.count {
                DispatchQueue.main.async { ripples = alive }
            }
        }
        .allowsHitTesting(false)
    }

    /// Static CRT-scanline overlay. Was previously a `GeometryReader` +
    /// `ForEach` of ~190 `Rectangle` views with a `withAnimation` driving
    /// `scanlineOffset` perpetually — that meant SwiftUI re-evaluated the
    /// view tree on every frame of the animation (60fps) just to slide
    /// stripes by 1px. The drift was barely visible at the 0.025 opacity
    /// the stripes already render at, so we drop the animation entirely
    /// and draw the static pattern in a single `Canvas`. Net change is
    /// imperceptible visually but huge for CPU.
    private var scanlines: some View {
        Canvas { context, size in
            let stripeHeight: CGFloat = 2
            let cycle = stripeHeight * 2
            let color = Color.white.opacity(0.025)
            var y: CGFloat = 0
            while y < size.height {
                let rect = CGRect(x: 0, y: y, width: size.width, height: stripeHeight)
                context.fill(Path(rect), with: .color(color))
                y += cycle
            }
        }
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }

    /// Animated character clip — fills the card edge-to-edge. Aspect
    /// mismatch between the 1:1.5 clip and the 1:1.9 card is handled by
    /// `.aspectRatio(.fill) + .clipped()` inside the player.
    ///
    /// The clips have alpha-channel transparent backgrounds (chroma-keyed
    /// from the AI's white BG at extraction time) so wherever the
    /// character isn't, the AvatarHero's drawn cyber backdrop shows
    /// through — no seams, no color mismatch.
    ///
    /// When the weather pill is shown we push the clip down a bit so her
    /// head clears the pill. The empty top region just shows more of the
    /// backdrop, which is what we want.
    private var character: some View {
        // 16 fps — the source clips were rendered at this rate by the AI
        // generator, so we play frames 1:1 for smooth motion.
        AnimatedAvatarPlayer(
            clip: playingMood.clipName,
            isLooping: playingMood.isLooping,
            fps: 16,
            verticalOffset: showWeather ? (compact ? 36 : 50) : 0,
            onFinished: { handleOneShotFinished() }
        )
    }

    private var cornerAccents: some View {
        VStack {
            HStack {
                HudBracket(corner: .topLeading)
                Spacer()
                HudBracket(corner: .topTrailing)
            }
            Spacer()
            HStack {
                HudBracket(corner: .bottomLeading)
                Spacer()
                HudBracket(corner: .bottomTrailing)
            }
        }
        .padding(compact ? 6 : 10)
        .allowsHitTesting(false)
    }

    private var weatherOverlay: some View {
        VStack {
            WeatherBubble(vm: weather)
                .padding(.top, compact ? 12 : 22)
            Spacer()
        }
    }

    private func particleLayer(now: Date) -> some View {
        Canvas { context, _ in
            var alive: [HeroParticle] = []
            for var p in particles {
                let elapsed = now.timeIntervalSince(p.bornAt)
                guard elapsed < p.lifetime else { continue }
                let t = elapsed / p.lifetime
                // Step constant matches the host TimelineView's 30 fps
                // tick rate.
                p.x += p.vx * (1.0 / 30.0)
                p.y += p.vy * (1.0 / 30.0)
                let opacity = max(0, 1.0 - t * 1.1)
                let pos = CGPoint(x: p.x, y: p.y)
                let symbolText = Text(Image(systemName: p.symbol))
                    .font(.system(size: p.size, weight: .semibold))
                    .foregroundStyle(p.color.opacity(opacity))
                context.draw(symbolText, at: pos)
                alive.append(p)
            }
            if alive.count != particles.count {
                DispatchQueue.main.async { particles = alive }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Loops

    private func startPerpetualLoops() {
        // Star twinkle is driven by TimelineView in starfield().
        // Scanlines used to drift via `withAnimation(.linear.repeatForever)`
        // here, but that ran at the display's refresh rate (60fps) and
        // forced a SwiftUI re-evaluation each frame. The drift was nearly
        // invisible at 0.025 opacity, so we dropped it. Nothing else needs
        // a perpetual loop — keeping the function as a stub in case we
        // ever want to bring one back.
        _ = scanlineOffset // (silence unused-state warning if ever)
    }

    private func scheduleAutoSleep() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5 * 60 * 1_000_000_000)
            guard !Task.isCancelled, mood == .idle, !autoSleeping else { return }
            autoSleeping = true
            playingMood = .sleeping
            withAnimation(.easeInOut(duration: 0.7)) {
                moodOpacity = 0.7
            }
            // Drip Z particles while sleeping.
            Task { @MainActor in
                while autoSleeping && !heroEvents.isListening {
                    spawnParticles(
                        count: 1,
                        symbol: "z.circle.fill",
                        color: CyberPalette.neonCyan.opacity(0.7),
                        sizeRange: 12...18,
                        upwardSpeed: 30...50,
                        lateralSpread: -8...8,
                        lifetime: 2.4,
                        originY: 100
                    )
                    try? await Task.sleep(nanoseconds: 1_400_000_000)
                }
            }
        }
    }

    private func wakeFromSleepIfNeeded() {
        guard autoSleeping else { return }
        autoSleeping = false
        withAnimation(.easeInOut(duration: 0.4)) {
            moodOpacity = 1.0
        }
    }

    // MARK: - Mood transitions

    private func handleMoodChange(_ new: HeroMood) {
        wakeFromSleepIfNeeded()
        // External `mood` change drops any in-flight one-shot.
        pendingOneShot = nil
        playingMood = new
        scheduleAutoSleep()
    }

    /// Fire a one-shot reaction — play that clip once, then revert to the
    /// underlying `mood`. Pink star particles still pop on celebration so
    /// the success isn't silent; other reactions just swap to their clip.
    private func fireOneShot(_ shot: HeroMood) {
        wakeFromSleepIfNeeded()
        pendingOneShot = shot
        playingMood = shot

        if shot == .celebrating {
            spawnParticles(
                count: 7,
                symbol: "sparkle",
                color: CyberPalette.neonPink,
                sizeRange: 11...18,
                upwardSpeed: 60...110,
                lateralSpread: -50...50,
                lifetime: 1.2,
                originY: 90
            )
        }
    }

    /// Called by AnimatedAvatarPlayer when a one-shot finishes playing.
    /// Revert to the underlying loop mood.
    private func handleOneShotFinished() {
        guard pendingOneShot != nil else { return }
        pendingOneShot = nil
        playingMood = mood
    }

    /// Listening — sustain the listening clip while voice capture is on.
    private func setListening(_ on: Bool) {
        if on {
            wakeFromSleepIfNeeded()
            playingMood = .listening
        } else {
            playingMood = mood
        }
    }

    // MARK: - Click handling

    /// Tap on the avatar card → spawn a ripple at the click point and
    /// trigger a one-shot reaction. Three+ rapid clicks within 0.6s
    /// switch the reaction from "greeting" to "confused" — she gets
    /// poke-fatigued.
    private func handleClick(at point: CGPoint) {
        // Spawn a ripple ring.
        ripples.append(Ripple(id: UUID(), origin: point, bornAt: Date(), lifetime: 1.2))

        // Track recent clicks for the rapid-poke detector.
        let now = Date()
        recentClicks = recentClicks.filter { now.timeIntervalSince($0) < 0.6 }
        recentClicks.append(now)

        if recentClicks.count >= 3 {
            recentClicks.removeAll()
            fireOneShot(.confused)
        } else {
            fireOneShot(.greeting)
        }
    }

    // MARK: - Particle helpers

    private func spawnParticles(
        count: Int,
        symbol: String,
        color: Color,
        sizeRange: ClosedRange<CGFloat>,
        upwardSpeed: ClosedRange<CGFloat>,
        lateralSpread: ClosedRange<CGFloat>,
        lifetime: TimeInterval,
        originY: CGFloat
    ) {
        let now = Date()
        var fresh: [HeroParticle] = []
        for _ in 0..<count {
            fresh.append(HeroParticle(
                id: UUID(),
                x: CGFloat.random(in: 80...120),
                y: originY + CGFloat.random(in: -10...10),
                vx: CGFloat.random(in: lateralSpread),
                vy: -CGFloat.random(in: upwardSpeed),
                size: CGFloat.random(in: sizeRange),
                symbol: symbol,
                color: color,
                bornAt: now,
                lifetime: lifetime
            ))
        }
        particles.append(contentsOf: fresh)
    }
}

// MARK: - Ripple model

/// One click ripple — an expanding ring centered on `origin`. Drawn by
/// `rippleLayer`; auto-evicted once `bornAt + lifetime` is in the past.
private struct Ripple: Identifiable {
    let id: UUID
    var origin: CGPoint
    var bornAt: Date
    var lifetime: TimeInterval
}

// MARK: - Star model

private struct HeroStar {
    /// Normalized 0..1 position within the card.
    var x: Double
    var y: Double
    /// Render diameter in points.
    var size: CGFloat
    /// Peak brightness — twinkle scales between 0 and this.
    var baseOpacity: Double
    var color: Color
    /// Radians per second.
    var twinkleSpeed: Double
    /// Initial offset in the twinkle sin wave (so stars don't pulse in sync).
    var twinklePhase: Double

    static func random() -> HeroStar {
        let r = Double.random(in: 0...1)
        let color: Color
        if r < 0.85 {
            color = .white
        } else if r < 0.93 {
            color = CyberPalette.neonCyan
        } else {
            color = CyberPalette.neonPink
        }
        return HeroStar(
            x: Double.random(in: 0...1),
            y: Double.random(in: 0...1),
            size: CGFloat.random(in: 0.6...2.4),
            baseOpacity: Double.random(in: 0.45...0.95),
            color: color,
            twinkleSpeed: Double.random(in: 1.0...3.2),
            twinklePhase: Double.random(in: 0...(2 * .pi))
        )
    }
}

// MARK: - Particle model

private struct HeroParticle: Identifiable {
    let id: UUID
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var size: CGFloat
    var symbol: String
    var color: Color
    var bornAt: Date
    var lifetime: TimeInterval
}

// MARK: - Time of day palette

private enum TimeOfDay {
    static func palette(for date: Date) -> (topHalo: Color, bottomRim: Color) {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<8:
            return (Color(red: 1.0, green: 0.65, blue: 0.45),
                    Color(red: 1.0, green: 0.40, blue: 0.55))
        case 8..<17:
            return (Color(red: 1.0, green: 0.30, blue: 0.75),
                    Color(red: 0.0, green: 0.85, blue: 1.0))
        case 17..<19:
            return (Color(red: 1.0, green: 0.40, blue: 0.55),
                    Color(red: 1.0, green: 0.55, blue: 0.30))
        case 19..<22:
            return (Color(red: 0.65, green: 0.35, blue: 0.95),
                    Color(red: 0.30, green: 0.55, blue: 1.0))
        default:
            return (Color(red: 0.45, green: 0.25, blue: 0.85),
                    Color(red: 0.20, green: 0.30, blue: 0.85))
        }
    }
}

// MARK: - Self chrome modifier

private struct SelfChromeModifier: ViewModifier {
    let enabled: Bool
    let compact: Bool

    func body(content: Content) -> some View {
        if enabled {
            let radius: CGFloat = compact ? 14 : 22
            content
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(CyberPalette.panelStroke, lineWidth: 1)
                )
        } else {
            content
        }
    }
}

// MARK: - HUD bracket

private struct HudBracket: View {
    enum Corner { case topLeading, topTrailing, bottomLeading, bottomTrailing }
    var corner: Corner
    var length: CGFloat = 14
    var thickness: CGFloat = 1.5

    var body: some View {
        let color = CyberPalette.neonCyan.opacity(0.55)
        ZStack {
            Rectangle()
                .fill(color)
                .frame(width: thickness, height: length)
                .offset(x: vOffsetX, y: 0)
            Rectangle()
                .fill(color)
                .frame(width: length, height: thickness)
                .offset(x: 0, y: hOffsetY)
        }
        .frame(width: length, height: length)
    }

    private var vOffsetX: CGFloat {
        switch corner {
        case .topLeading, .bottomLeading: return -length/2 + thickness/2
        case .topTrailing, .bottomTrailing: return length/2 - thickness/2
        }
    }
    private var hOffsetY: CGFloat {
        switch corner {
        case .topLeading, .topTrailing: return -length/2 + thickness/2
        case .bottomLeading, .bottomTrailing: return length/2 - thickness/2
        }
    }
}
