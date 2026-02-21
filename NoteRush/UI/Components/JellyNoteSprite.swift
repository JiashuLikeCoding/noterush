import SwiftUI

/// Jelly Note Sprite (water drop body + small note on head).
/// Used as a small decorative mascot; keep it subtle.
struct JellyNoteSprite: View {
    enum Mood {
        case idle
        case happy
        case sad
    }

    var mood: Mood = .idle

    var body: some View {
        ZStack {
            // Body
            DropletShape()
                .fill(
                    LinearGradient(
                        colors: [KidTheme.primary.opacity(0.92), KidTheme.accent.opacity(0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    DropletShape()
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: KidTheme.shadow.opacity(0.75), radius: 10, x: 0, y: 6)

            // Face
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    Circle().fill(Color.white.opacity(0.9)).frame(width: 6, height: 6)
                    Circle().fill(Color.white.opacity(0.9)).frame(width: 6, height: 6)
                }
                .padding(.top, 6)

                Capsule()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 16, height: 4)
                    .scaleEffect(y: mouthScaleY, anchor: .center)
            }
            .offset(y: 2)

            // Head note
            Image(systemName: "music.note")
                .font(.system(size: 14, weight: .heavy))
                .foregroundColor(Color.white.opacity(0.92))
                .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                .offset(x: 12, y: -26)
        }
        .frame(width: 64, height: 64)
        .opacity(0.95)
    }

    private var mouthScaleY: CGFloat {
        switch mood {
        case .idle: return 0.55
        case .happy: return 1.0
        case .sad: return 0.2
        }
    }
}

private struct DropletShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height

        // A simple droplet using quad curves.
        let top = CGPoint(x: w * 0.5, y: h * 0.10)
        let left = CGPoint(x: w * 0.18, y: h * 0.52)
        let right = CGPoint(x: w * 0.82, y: h * 0.52)
        let bottom = CGPoint(x: w * 0.50, y: h * 0.92)

        p.move(to: top)
        p.addQuadCurve(to: left, control: CGPoint(x: w * 0.20, y: h * 0.22))
        p.addQuadCurve(to: bottom, control: CGPoint(x: w * 0.10, y: h * 0.80))
        p.addQuadCurve(to: right, control: CGPoint(x: w * 0.90, y: h * 0.80))
        p.addQuadCurve(to: top, control: CGPoint(x: w * 0.80, y: h * 0.22))
        p.closeSubpath()
        return p
    }
}
