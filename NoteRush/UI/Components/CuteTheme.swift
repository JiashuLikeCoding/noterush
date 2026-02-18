import SwiftUI

enum CuteTheme {
    private static var palette: ThemePalette {
        AppTheme.current.palette
    }

    // Background
    static var backgroundTop: Color { palette.backgroundTop }
    static var backgroundBottom: Color { palette.backgroundBottom }

    // Surfaces
    static var cardBackground: Color { palette.cardBackground }
    static var cardBorder: Color { palette.cardBorder }
    static var cardShadow: Color { palette.cardShadow }

    // Text
    static var textPrimary: Color { palette.textPrimary }
    static var textSecondary: Color { palette.textSecondary }

    // Accent
    static var accent: Color { palette.accent }
    static var accentPressed: Color { palette.accentPressed }
    static var feedbackSuccess: Color { palette.feedbackSuccess }
    static var feedbackMiss: Color { palette.feedbackMiss }

    // Judgement colors (fixed): correct = green, wrong = red
    static var judgementCorrect: Color { .green }
    static var judgementWrong: Color { .red }

    // Register accents
    static var lowAccent: Color { palette.lowAccent }
    static var midAccent: Color { palette.midAccent }
    static var highAccent: Color { palette.highAccent }

    // Controls
    static var controlFill: Color { palette.controlFill }
    static var controlFillPressed: Color { palette.controlFillPressed }
    static var controlBorder: Color { palette.controlBorder }
    static var chipFill: Color { palette.chipFill }
    static var chipSelectedFill: Color { palette.chipSelectedFill }
    static var chipBorder: Color { palette.chipBorder }
    static var clefOpacity: Double { palette.clefOpacity }
    static var staffLineColor: Color { palette.staffLineColor }

    enum FontSize {
        // One step smaller across the app (Jason request)
        static let titleXL: CGFloat = 30
        static let title: CGFloat = 18
        static let section: CGFloat = 15
        static let body: CGFloat = 13
        static let caption: CGFloat = 11
        static let button: CGFloat = 16
        static let buttonSmall: CGFloat = 11
        static let nav: CGFloat = 13
    }

    /// Canonical note/letter colors used across staff + keyboard when "colored notes" is enabled.
    /// Chosen to be a bit softer / more UI-friendly while staying clearly distinct.
    static func noteColor(for letter: NoteLetter) -> Color {
        switch letter {
        case .c:
            // coral red
            return Color(red: 0.91, green: 0.36, blue: 0.36)
        case .d:
            // fresh green
            return Color(red: 0.30, green: 0.69, blue: 0.33)
        case .e:
            // bright blue
            return Color(red: 0.29, green: 0.49, blue: 0.97)
        case .f:
            // warm orange
            return Color(red: 0.95, green: 0.64, blue: 0.23)
        case .g:
            // teal
            return Color(red: 0.21, green: 0.72, blue: 0.77)
        case .a:
            // pink
            return Color(red: 0.90, green: 0.35, blue: 0.69)
        case .b:
            // purple
            return Color(red: 0.61, green: 0.42, blue: 0.97)
        }
    }
}

extension View {
    func zenBackground() -> some View {
        self.background(
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [CuteTheme.backgroundTop, CuteTheme.backgroundBottom]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Circle()
                    .fill(CuteTheme.accent.opacity(0.08))
                    .frame(width: 260, height: 260)
                    .blur(radius: 12)
                    .offset(x: -140, y: -220)

                Circle()
                    .fill(CuteTheme.lowAccent.opacity(0.08))
                    .frame(width: 220, height: 220)
                    .blur(radius: 10)
                    .offset(x: 150, y: -60)

                Circle()
                    .fill(CuteTheme.highAccent.opacity(0.07))
                    .frame(width: 260, height: 260)
                    .blur(radius: 14)
                    .offset(x: 120, y: 220)
            }
        )
    }

    func cuteBackground() -> some View {
        self.background(
            LinearGradient(
                gradient: Gradient(colors: [CuteTheme.backgroundTop, CuteTheme.backgroundBottom]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    func cuteCard() -> some View {
        self
            .background(CuteTheme.cardBackground)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(CuteTheme.cardBorder, lineWidth: 1)
            )
            .shadow(color: CuteTheme.cardShadow, radius: 16, x: 0, y: 10)
    }
}
