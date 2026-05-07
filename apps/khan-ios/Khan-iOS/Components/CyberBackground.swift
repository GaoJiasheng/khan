import SwiftUI
import KhanUI

/// Full-screen ambient backdrop — deep purple→black gradient with breathing
/// pink and cyan radial halos and a faint CRT scanline overlay. Used as the
/// root background of every iOS screen so the cyber aesthetic is consistent
/// from launch to shutdown.
struct CyberBackground: View {
    @State private var glowPhase: Double = 0
    @State private var scanlineOffset: CGFloat = 0

    var body: some View {
        ZStack {
            CyberPalette.backdrop
                .ignoresSafeArea()
            // Pink halo top-left
            RadialGradient(
                colors: [CyberPalette.neonPink.opacity(0.22), .clear],
                center: UnitPoint(x: 0.18, y: 0.18),
                startRadius: 4, endRadius: 280
            )
            .blur(radius: 20)
            .opacity(0.6 + glowPhase * 0.4)
            .ignoresSafeArea()
            // Cyan rim bottom-right
            RadialGradient(
                colors: [CyberPalette.neonCyan.opacity(0.18), .clear],
                center: UnitPoint(x: 0.82, y: 0.95),
                startRadius: 0, endRadius: 320
            )
            .blur(radius: 16)
            .ignoresSafeArea()
            scanlines
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                glowPhase = 1
            }
            withAnimation(.linear(duration: 9).repeatForever(autoreverses: false)) {
                scanlineOffset = 1
            }
        }
    }

    private var scanlines: some View {
        GeometryReader { geo in
            let stripeHeight: CGFloat = 2
            let count = Int(geo.size.height / stripeHeight) + 4
            VStack(spacing: 0) {
                ForEach(0..<count, id: \.self) { i in
                    Rectangle()
                        .fill(i.isMultiple(of: 2) ? Color.white.opacity(0.018) : Color.clear)
                        .frame(height: stripeHeight)
                }
            }
            .offset(y: -scanlineOffset * stripeHeight * 2)
            .blendMode(.plusLighter)
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

/// Reusable card surface with neon stroke + glass fill. Drop content inside
/// to get the same panel look used in the Mac expanded view.
struct CyberCard<Content: View>: View {
    var cornerRadius: CGFloat = 18
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color.black.opacity(0.55), Color.black.opacity(0.30)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .opacity(0.4)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(CyberPalette.panelStroke, lineWidth: 0.8)
            )
    }
}
