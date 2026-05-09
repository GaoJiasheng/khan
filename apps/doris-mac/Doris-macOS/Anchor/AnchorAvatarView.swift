import SwiftUI
import AppKit

enum AvatarState: Equatable {
    case idle
    case click
    case notify
    case expanded
}

/// Cyberpunk avatar slot. Falls back to a procedural neon-glyph if no PNG is bundled.
/// State changes drive reaction animations; the underlying art is whatever drops into
/// `apps/doris-mac/Doris-macOS/Resources/Avatar/`.
struct AnchorAvatarView: View {
    let state: AvatarState
    var size: CGFloat = 24

    @State private var clickTrigger: Int = 0
    @State private var notifyTrigger: Int = 0
    @State private var idlePhase: Double = 0
    @State private var glowPulse: Double = 0

    var body: some View {
        ZStack {
            // Soft neon backdrop glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.25, blue: 0.7).opacity(0.45),
                            Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.20),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.9
                    )
                )
                .frame(width: size * 1.6, height: size * 1.6)
                .opacity(0.6 + glowPulse * 0.4)
                .blur(radius: 4)

            avatarArt
                .scaleEffect(reactionScale)
                .rotationEffect(.degrees(reactionRotation))
                .shadow(color: Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.55), radius: 4)
        }
        .frame(width: size, height: size)
        .onChange(of: state) { _, newState in
            switch newState {
            case .click:
                clickTrigger += 1
            case .notify:
                notifyTrigger += 1
            case .idle, .expanded:
                break
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                idlePhase = 1
            }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                glowPulse = 1
            }
        }
        // React to click trigger via keyframe animation
        .keyframeAnimator(
            initialValue: ReactionFrame(),
            trigger: clickTrigger
        ) { content, value in
            content
                .scaleEffect(value.scale)
                .rotationEffect(.degrees(value.rotation))
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                LinearKeyframe(1.0, duration: 0)
                SpringKeyframe(1.25, duration: 0.12, spring: .snappy)
                SpringKeyframe(1.0, duration: 0.28, spring: .bouncy)
            }
            KeyframeTrack(\.rotation) {
                LinearKeyframe(0, duration: 0)
                SpringKeyframe(-8, duration: 0.10)
                SpringKeyframe(6, duration: 0.10)
                SpringKeyframe(0, duration: 0.20)
            }
        }
        // React to notify trigger
        .keyframeAnimator(
            initialValue: ReactionFrame(),
            trigger: notifyTrigger
        ) { content, value in
            content
                .scaleEffect(value.scale)
                .offset(y: value.bounce)
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                LinearKeyframe(1.0, duration: 0)
                SpringKeyframe(1.4, duration: 0.18, spring: .snappy)
                SpringKeyframe(0.95, duration: 0.20, spring: .bouncy)
                SpringKeyframe(1.0, duration: 0.22, spring: .smooth)
            }
            KeyframeTrack(\.bounce) {
                LinearKeyframe(0, duration: 0)
                SpringKeyframe(-3, duration: 0.18)
                SpringKeyframe(0, duration: 0.30)
            }
        }
    }

    // MARK: - Subtle idle motion

    private var reactionScale: CGFloat {
        // Tiny breathing
        1.0 + 0.03 * idlePhase
    }
    private var reactionRotation: Double {
        // Imperceptible head-tilt
        idlePhase * 1.0 - 0.5
    }

    // MARK: - Art (PNG asset → procedural fallback)

    @ViewBuilder
    private var avatarArt: some View {
        if let nsImage = bundledAvatarImage() {
            Image(nsImage: cropToHeadSquare(nsImage))
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            CyberKGlyph()
                .frame(width: size, height: size)
        }
    }

    /// Crop a portrait avatar to a square focused on the head/shoulders.
    /// Assumes the head occupies roughly the top 40% of a portrait image.
    private func cropToHeadSquare(_ image: NSImage) -> NSImage {
        let imgSize = image.size
        // Choose a square crop sized to the image width (or 70% of height for safety),
        // anchored toward the top so the head is visible.
        let side = min(imgSize.width, imgSize.height * 0.7)
        // NSImage coordinate origin is bottom-left → "top" = imgSize.height - side
        let srcOriginY = max(0, imgSize.height - side - imgSize.height * 0.05) // tiny breathing room above the head
        let srcOriginX = (imgSize.width - side) / 2
        let srcRect = NSRect(x: srcOriginX, y: srcOriginY, width: side, height: side)

        let cropped = NSImage(size: NSSize(width: side, height: side))
        cropped.lockFocus()
        image.draw(
            in: NSRect(x: 0, y: 0, width: side, height: side),
            from: srcRect,
            operation: .sourceOver,
            fraction: 1.0
        )
        cropped.unlockFocus()
        return cropped
    }

    private func bundledAvatarImage() -> NSImage? {
        let candidates = ["doris-avatar", "doris-avatar-idle"]
        for name in candidates {
            if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Avatar") {
                if let img = NSImage(contentsOf: url) { return img }
            }
            if let url = Bundle.main.url(forResource: name, withExtension: "png") {
                if let img = NSImage(contentsOf: url) { return img }
            }
        }
        return nil
    }
}

private struct ReactionFrame: Equatable {
    var scale: CGFloat = 1.0
    var rotation: Double = 0
    var bounce: CGFloat = 0
}

/// Procedural fallback: a stylised "K" glyph with neon cyan/pink gradient.
private struct CyberKGlyph: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.25, blue: 0.75),
                            Color(red: 0.0, green: 0.85, blue: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
            Text("K")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.85, blue: 1.0),
                            Color(red: 0.6, green: 1.0, blue: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: Color(red: 1.0, green: 0.25, blue: 0.85).opacity(0.7), radius: 3)
        }
    }
}
