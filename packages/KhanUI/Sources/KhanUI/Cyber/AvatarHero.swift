import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Cross-platform cyber-girl hero card. Same neon vocabulary on Mac and iOS:
/// pink head halo, cyan foot rim, CRT scanlines, HUD corner brackets.
/// Hosts the bundled avatar PNG; falls back to a "KHAN" badge if the asset
/// isn't found.
public struct AvatarHero: View {
    public enum HeroState { case idle, alerted }
    var state: HeroState
    var compact: Bool

    public init(state: HeroState = .idle, compact: Bool = false) {
        self.state = state
        self.compact = compact
    }

    @State private var glowPhase: Double = 0
    @State private var scanlineOffset: CGFloat = 0

    public var body: some View {
        ZStack {
            backdrop
            scanlines
            character
            cornerAccents
        }
        .clipShape(RoundedRectangle(cornerRadius: compact ? 14 : 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 14 : 22, style: .continuous)
                .strokeBorder(CyberPalette.panelStroke, lineWidth: 1)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) {
                glowPhase = 1
            }
            withAnimation(.linear(duration: 7).repeatForever(autoreverses: false)) {
                scanlineOffset = 1
            }
        }
    }

    // MARK: - Layers

    /// The hero stage stays visually dark even in the light cyber theme —
    /// the character was painted on a dark background and looks washed out
    /// against cream. So this gradient is fixed, not adaptive.
    private var backdrop: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.06, blue: 0.18),
                    Color(red: 0.02, green: 0.02, blue: 0.05)
                ],
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(
                colors: [CyberPalette.neonPink.opacity(0.30), .clear],
                center: UnitPoint(x: 0.5, y: 0.32),
                startRadius: 4, endRadius: 140
            )
            .blur(radius: 12)
            .opacity(0.7 + glowPhase * 0.4)
            RadialGradient(
                colors: [CyberPalette.neonCyan.opacity(0.22), .clear],
                center: UnitPoint(x: 0.5, y: 1.0),
                startRadius: 0, endRadius: 200
            )
            .blur(radius: 10)
        }
    }

    private var scanlines: some View {
        GeometryReader { geo in
            let stripeHeight: CGFloat = 2
            let count = Int(geo.size.height / stripeHeight) + 2
            VStack(spacing: 0) {
                ForEach(0..<count, id: \.self) { i in
                    Rectangle()
                        .fill(i.isMultiple(of: 2) ? Color.white.opacity(0.025) : Color.clear)
                        .frame(height: stripeHeight)
                }
            }
            .offset(y: -scanlineOffset * stripeHeight * 2)
            .blendMode(.plusLighter)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var character: some View {
        if let img = Self.platformAvatarImage {
            #if os(macOS)
            Image(nsImage: img)
                .resizable()
                .scaledToFit()
                .padding(.horizontal, compact ? 6 : 12)
                .padding(.top, compact ? 12 : 24)
                .padding(.bottom, compact ? 0 : -2)
                .shadow(color: CyberPalette.neonCyan.opacity(0.35), radius: 8)
                .scaleEffect(state == .alerted ? 1.05 : 1.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: state)
            #else
            Image(uiImage: img)
                .resizable()
                .scaledToFit()
                .padding(.horizontal, compact ? 6 : 12)
                .padding(.top, compact ? 12 : 24)
                .padding(.bottom, compact ? 0 : -2)
                .shadow(color: CyberPalette.neonCyan.opacity(0.35), radius: 8)
                .scaleEffect(state == .alerted ? 1.05 : 1.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: state)
            #endif
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            Circle().stroke(CyberPalette.panelStroke, lineWidth: 1.5)
            Text("KHAN")
                .font(.system(size: compact ? 16 : 24, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: compact ? 64 : 110, height: compact ? 64 : 110)
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

    // MARK: - Image loader

    #if os(macOS)
    private static let platformAvatarImage: NSImage? = {
        let candidates = ["khan-avatar-fullbody", "khan-avatar"]
        for name in candidates {
            if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Avatar"),
               let img = NSImage(contentsOf: url) { return img }
            if let url = Bundle.main.url(forResource: name, withExtension: "png"),
               let img = NSImage(contentsOf: url) { return img }
            if let img = Bundle.main.image(forResource: name) { return img }
        }
        return nil
    }()
    #else
    private static let platformAvatarImage: UIImage? = {
        let candidates = ["khan-avatar-fullbody", "khan-avatar"]
        for name in candidates {
            if let img = UIImage(named: name) { return img }
            if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Avatar"),
               let data = try? Data(contentsOf: url),
               let img = UIImage(data: data) { return img }
        }
        return nil
    }()
    #endif
}

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
