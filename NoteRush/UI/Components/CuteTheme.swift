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

    static func noteColor(for letter: NoteLetter) -> Color {
        switch letter {
        case .c:
            return Color(red: 0.78, green: 0.16, blue: 0.16)
        case .d:
            return Color(red: 0.18, green: 0.46, blue: 0.12)
        case .e:
            return Color(red: 0.20, green: 0.36, blue: 0.78)
        case .f:
            return Color(red: 0.60, green: 0.26, blue: 0.10)
        case .g:
            return Color(red: 0.10, green: 0.48, blue: 0.58)
        case .a:
            return Color(red: 0.78, green: 0.12, blue: 0.52)
        case .b:
            return Color(red: 0.55, green: 0.24, blue: 0.75)
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
