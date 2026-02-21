import SwiftUI

/// Kid-friendly "jelly" theme (blue + pink) for the full UI refresh.
/// This is intentionally self-contained so we can migrate screen-by-screen.
enum KidTheme {
    // MARK: - Colors

    // Background gradient
    static let bgTop = Color(red: 0.92, green: 0.97, blue: 1.00)
    static let bgBottom = Color(red: 0.98, green: 0.96, blue: 1.00)

    // Primary / accent
    static let primary = Color(red: 0.22, green: 0.62, blue: 0.98) // sky blue
    static let primaryPressed = Color(red: 0.15, green: 0.52, blue: 0.92)

    static let accent = Color(red: 1.00, green: 0.45, blue: 0.78) // pink
    static let accentPressed = Color(red: 0.92, green: 0.36, blue: 0.70)

    // Feedback
    static let success = Color(red: 0.20, green: 0.80, blue: 0.55)
    static let danger = Color(red: 0.98, green: 0.32, blue: 0.36)

    // Surfaces
    static let surface = Color.white.opacity(0.92)
    static let surfaceStrong = Color.white
    static let border = Color.black.opacity(0.08)
    static let shadow = Color.black.opacity(0.10)

    // Text
    static let textPrimary = Color(red: 0.11, green: 0.16, blue: 0.22)
    static let textSecondary = Color.black.opacity(0.55)

    // MARK: - Layout

    enum Radius {
        static let card: CGFloat = 24
        static let button: CGFloat = 22
        static let chip: CGFloat = 14
    }

    enum FontSize {
        static let hero: CGFloat = 24
        static let title: CGFloat = 18
        static let subtitle: CGFloat = 13
        static let body: CGFloat = 14
        static let caption: CGFloat = 12
        static let tiny: CGFloat = 11
    }
}

extension View {
    func kidBackground() -> some View {
        background(
            ZStack {
                LinearGradient(
                    colors: [KidTheme.bgTop, KidTheme.bgBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                // Soft blobs
                Circle()
                    .fill(KidTheme.primary.opacity(0.10))
                    .frame(width: 280, height: 280)
                    .blur(radius: 18)
                    .offset(x: -160, y: -240)

                Circle()
                    .fill(KidTheme.accent.opacity(0.10))
                    .frame(width: 240, height: 240)
                    .blur(radius: 18)
                    .offset(x: 170, y: -70)

                Circle()
                    .fill(KidTheme.primary.opacity(0.08))
                    .frame(width: 320, height: 320)
                    .blur(radius: 24)
                    .offset(x: 120, y: 260)
            }
        )
    }
}
