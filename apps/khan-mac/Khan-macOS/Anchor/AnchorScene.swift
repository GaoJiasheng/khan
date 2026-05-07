import SwiftUI
import AppKit
import KhanUI

/// Scene state — drives the avatar's pose / animation. Right now we have one static
/// pose (idle); future states will trigger sprite swaps, scale bounces, etc.
enum AnchorSceneState: Equatable {
    case idle
    case greeting   // user just opened the panel
    case alerted    // a notification just arrived
}

/// The "stage" inside the expanded panel — the cyberpunk girl on a neon backdrop.
/// Lives on the LEFT column of the panel; designed to be the visual anchor of the UI.
struct AnchorSceneView: View {
    var state: AnchorSceneState = .idle

    @StateObject private var weather = WeatherViewModel()
    @State private var glowPhase: Double = 0
    @State private var scanlineOffset: CGFloat = 0

    private static let fullbody: NSImage? = {
        let candidates = ["khan-avatar-fullbody", "khan-avatar"]
        for name in candidates {
            if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Avatar"),
               let img = NSImage(contentsOf: url) { return img }
            if let url = Bundle.main.url(forResource: name, withExtension: "png"),
               let img = NSImage(contentsOf: url) { return img }
        }
        return nil
    }()

    var body: some View {
        ZStack {
            backdrop
            scanlines
            character
            cornerAccents
            weatherOverlay
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) {
                glowPhase = 1
            }
            withAnimation(.linear(duration: 7).repeatForever(autoreverses: false)) {
                scanlineOffset = 1
            }
            weather.start()
        }
        .onDisappear {
            weather.stop()
        }
    }

    /// Floating weather pill, top-center inside the corner brackets.
    private var weatherOverlay: some View {
        VStack {
            WeatherBubble(vm: weather)
                .padding(.top, 22)
            Spacer()
        }
    }

    // Soft cyan / pink radial glow that breathes
    private var backdrop: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.06, blue: 0.10),
                    Color(red: 0.02, green: 0.02, blue: 0.05)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            // Pink halo behind the head
            RadialGradient(
                colors: [Color(red: 1.0, green: 0.30, blue: 0.75).opacity(0.25), .clear],
                center: UnitPoint(x: 0.5, y: 0.32),
                startRadius: 4, endRadius: 80
            )
            .blur(radius: 8)
            .opacity(0.7 + glowPhase * 0.4)
            // Cyan rim from below
            RadialGradient(
                colors: [Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.20), .clear],
                center: UnitPoint(x: 0.5, y: 1.0),
                startRadius: 0, endRadius: 120
            )
            .blur(radius: 6)
        }
    }

    private var scanlines: some View {
        // Faint horizontal lines that drift downward — adds CRT / cyber texture.
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
            if let img = Self.fullbody {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .padding(.horizontal, 8)
                    .padding(.bottom, -4) // bleed a couple pts off the bottom
                    .padding(.top, 12)
                    .shadow(color: Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.4), radius: 6)
            } else {
                placeholder
            }
        }
        .scaleEffect(state == .alerted ? 1.05 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: state)
    }

    private var placeholder: some View {
        ZStack {
            Circle().stroke(LinearGradient(
                colors: [Color(red: 1.0, green: 0.25, blue: 0.75), Color(red: 0.0, green: 0.85, blue: 1.0)],
                startPoint: .top, endPoint: .bottom
            ), lineWidth: 1.5)
            Text("KHAN")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: 100, height: 100)
    }

    /// Decorative corner brackets — gives a HUD / sci-fi feel.
    private var cornerAccents: some View {
        VStack {
            HStack {
                Bracket(corner: .topLeading)
                Spacer()
                Bracket(corner: .topTrailing)
            }
            Spacer()
            HStack {
                Bracket(corner: .bottomLeading)
                Spacer()
                Bracket(corner: .bottomTrailing)
            }
        }
        .padding(8)
        .allowsHitTesting(false)
    }
}

private struct Bracket: View {
    enum Corner { case topLeading, topTrailing, bottomLeading, bottomTrailing }
    var corner: Corner
    var length: CGFloat = 14
    var thickness: CGFloat = 1.5

    var body: some View {
        let color = Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.55)
        ZStack {
            // Vertical leg
            Rectangle()
                .fill(color)
                .frame(width: thickness, height: length)
                .offset(x: vOffsetX, y: vOffsetY)
            // Horizontal leg
            Rectangle()
                .fill(color)
                .frame(width: length, height: thickness)
                .offset(x: hOffsetX, y: hOffsetY)
        }
        .frame(width: length, height: length)
    }

    private var vOffsetX: CGFloat {
        switch corner { case .topLeading, .bottomLeading: return -length/2 + thickness/2; case .topTrailing, .bottomTrailing: return length/2 - thickness/2 }
    }
    private var vOffsetY: CGFloat {
        switch corner { case .topLeading, .topTrailing: return -length/2 + length/2; case .bottomLeading, .bottomTrailing: return length/2 - length/2 }
    }
    private var hOffsetX: CGFloat {
        switch corner { case .topLeading, .bottomLeading: return -length/2 + length/2; case .topTrailing, .bottomTrailing: return length/2 - length/2 }
    }
    private var hOffsetY: CGFloat {
        switch corner { case .topLeading, .topTrailing: return -length/2 + thickness/2; case .bottomLeading, .bottomTrailing: return length/2 - thickness/2 }
    }
}
