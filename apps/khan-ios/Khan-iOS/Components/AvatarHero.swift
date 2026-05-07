import SwiftUI
import KhanUI

/// iOS counterpart of the Mac AnchorScene — same neon vocabulary (pink head
/// halo, cyan foot rim, CRT scanlines, HUD corner brackets) sized for a
/// phone-width hero card. Hosts the avatar PNG; falls back to a "KHAN" badge
/// if the asset isn't bundled.
struct AvatarHero: View {
    enum State { case idle, alerted }
    var state: State = .idle

    @State private var glowPhase: Double = 0
    @State private var scanlineOffset: CGFloat = 0

    var body: some View {
        ZStack {
            backdrop
            scanlines
            character
            cornerAccents
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
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

    private var backdrop: some View {
        ZStack {
            CyberPalette.backdrop
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

    private var character: some View {
        Group {
            if let img = Self.avatarImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .padding(.horizontal, 12)
                    .padding(.top, 24)
                    .padding(.bottom, -2)
                    .shadow(color: CyberPalette.neonCyan.opacity(0.35), radius: 8)
            } else {
                placeholder
            }
        }
        .scaleEffect(state == .alerted ? 1.05 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: state)
    }

    private var placeholder: some View {
        ZStack {
            Circle().stroke(CyberPalette.panelStroke, lineWidth: 1.5)
            Text("KHAN")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: 110, height: 110)
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
        .padding(10)
        .allowsHitTesting(false)
    }

    /// Loads the bundled avatar — same asset the Mac uses for the anchor
    /// scene. Tries both the cropped face and the fullbody variant; whichever
    /// landed in the iOS bundle.
    private static let avatarImage: UIImage? = {
        let candidates = ["khan-avatar-fullbody", "khan-avatar"]
        for name in candidates {
            if let img = UIImage(named: name) { return img }
            if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Avatar"),
               let data = try? Data(contentsOf: url),
               let img = UIImage(data: data) {
                return img
            }
        }
        return nil
    }()
}

/// Tiny HUD-style L-bracket. Pure SwiftUI shapes, no images, so it scales.
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
                .offset(x: vOffsetX, y: vOffsetY)
            Rectangle()
                .fill(color)
                .frame(width: length, height: thickness)
                .offset(x: hOffsetX, y: hOffsetY)
        }
        .frame(width: length, height: length)
    }

    private var vOffsetX: CGFloat {
        switch corner {
        case .topLeading, .bottomLeading: return -length/2 + thickness/2
        case .topTrailing, .bottomTrailing: return length/2 - thickness/2
        }
    }
    private var vOffsetY: CGFloat { 0 }
    private var hOffsetX: CGFloat { 0 }
    private var hOffsetY: CGFloat {
        switch corner {
        case .topLeading, .topTrailing: return -length/2 + thickness/2
        case .bottomLeading, .bottomTrailing: return length/2 - thickness/2
        }
    }
}
