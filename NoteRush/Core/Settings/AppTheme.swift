import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case zen
    case mist
    case sand
    case ink
    case mono

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .zen:
            return "Zen"
        case .mist:
            return "Mist"
        case .sand:
            return "Sand"
        case .ink:
            return "Ink"
        case .mono:
            return "Mono"
        }
    }

    var palette: ThemePalette {
        switch self {
        case .zen:
            return ThemePalette(
                backgroundTop: Color(red: 0.96, green: 0.95, blue: 0.92),
                backgroundBottom: Color(red: 0.90, green: 0.94, blue: 0.90),
                cardBackground: Color(red: 0.99, green: 0.98, blue: 0.96),
                cardBorder: Color.black.opacity(0.08),
                cardShadow: Color.black.opacity(0.08),
                textPrimary: Color(red: 0.17, green: 0.16, blue: 0.15),
                textSecondary: Color(red: 0.43, green: 0.40, blue: 0.38),
                accent: Color(red: 0.20, green: 0.46, blue: 0.36),
                accentPressed: Color(red: 0.16, green: 0.38, blue: 0.30),
                lowAccent: Color(red: 0.14, green: 0.36, blue: 0.78),
                midAccent: Color(red: 0.10, green: 0.56, blue: 0.38),
                highAccent: Color(red: 0.52, green: 0.22, blue: 0.82),
                controlFill: Color(red: 0.93, green: 0.92, blue: 0.90),
                controlFillPressed: Color(red: 0.88, green: 0.86, blue: 0.84),
                controlBorder: Color.black.opacity(0.12),
                chipFill: Color(red: 0.95, green: 0.94, blue: 0.92),
                chipSelectedFill: Color(red: 0.87, green: 0.90, blue: 0.86),
                chipBorder: Color.black.opacity(0.12),
                feedbackSuccess: Color(red: 0.20, green: 0.46, blue: 0.36),
                feedbackMiss: Color(red: 0.70, green: 0.38, blue: 0.30),
                staffLineColor: Color.black.opacity(0.22),
                clefOpacity: 0.32
            )
        case .mist:
            return ThemePalette(
                backgroundTop: Color(red: 0.93, green: 0.96, blue: 0.98),
                backgroundBottom: Color(red: 0.88, green: 0.93, blue: 0.97),
                cardBackground: Color(red: 0.98, green: 0.99, blue: 1.0),
                cardBorder: Color.black.opacity(0.07),
                cardShadow: Color.black.opacity(0.07),
                textPrimary: Color(red: 0.18, green: 0.20, blue: 0.24),
                textSecondary: Color(red: 0.42, green: 0.46, blue: 0.52),
                accent: Color(red: 0.22, green: 0.46, blue: 0.66),
                accentPressed: Color(red: 0.18, green: 0.38, blue: 0.56),
                lowAccent: Color(red: 0.24, green: 0.42, blue: 0.76),
                midAccent: Color(red: 0.20, green: 0.58, blue: 0.64),
                highAccent: Color(red: 0.46, green: 0.32, blue: 0.78),
                controlFill: Color(red: 0.92, green: 0.94, blue: 0.97),
                controlFillPressed: Color(red: 0.88, green: 0.91, blue: 0.95),
                controlBorder: Color.black.opacity(0.10),
                chipFill: Color(red: 0.94, green: 0.96, blue: 0.98),
                chipSelectedFill: Color(red: 0.86, green: 0.92, blue: 0.98),
                chipBorder: Color.black.opacity(0.10),
                feedbackSuccess: Color(red: 0.22, green: 0.46, blue: 0.66),
                feedbackMiss: Color(red: 0.76, green: 0.40, blue: 0.38),
                staffLineColor: Color.black.opacity(0.20),
                clefOpacity: 0.28
            )
        case .sand:
            return ThemePalette(
                backgroundTop: Color(red: 0.98, green: 0.95, blue: 0.90),
                backgroundBottom: Color(red: 0.93, green: 0.90, blue: 0.85),
                cardBackground: Color(red: 1.0, green: 0.98, blue: 0.94),
                cardBorder: Color.black.opacity(0.08),
                cardShadow: Color.black.opacity(0.08),
                textPrimary: Color(red: 0.22, green: 0.18, blue: 0.14),
                textSecondary: Color(red: 0.46, green: 0.40, blue: 0.34),
                accent: Color(red: 0.66, green: 0.44, blue: 0.26),
                accentPressed: Color(red: 0.56, green: 0.36, blue: 0.22),
                lowAccent: Color(red: 0.62, green: 0.36, blue: 0.22),
                midAccent: Color(red: 0.46, green: 0.56, blue: 0.32),
                highAccent: Color(red: 0.62, green: 0.40, blue: 0.32),
                controlFill: Color(red: 0.94, green: 0.91, blue: 0.86),
                controlFillPressed: Color(red: 0.90, green: 0.86, blue: 0.80),
                controlBorder: Color.black.opacity(0.12),
                chipFill: Color(red: 0.96, green: 0.93, blue: 0.88),
                chipSelectedFill: Color(red: 0.92, green: 0.88, blue: 0.82),
                chipBorder: Color.black.opacity(0.12),
                feedbackSuccess: Color(red: 0.44, green: 0.56, blue: 0.32),
                feedbackMiss: Color(red: 0.70, green: 0.38, blue: 0.30),
                staffLineColor: Color.black.opacity(0.22),
                clefOpacity: 0.30
            )
        case .ink:
            return ThemePalette(
                backgroundTop: Color(red: 0.94, green: 0.95, blue: 0.96),
                backgroundBottom: Color(red: 0.90, green: 0.92, blue: 0.94),
                cardBackground: Color(red: 0.99, green: 0.99, blue: 1.0),
                cardBorder: Color.black.opacity(0.10),
                cardShadow: Color.black.opacity(0.10),
                textPrimary: Color(red: 0.16, green: 0.17, blue: 0.20),
                textSecondary: Color(red: 0.42, green: 0.44, blue: 0.50),
                accent: Color(red: 0.30, green: 0.36, blue: 0.48),
                accentPressed: Color(red: 0.24, green: 0.30, blue: 0.40),
                lowAccent: Color(red: 0.30, green: 0.36, blue: 0.62),
                midAccent: Color(red: 0.24, green: 0.50, blue: 0.52),
                highAccent: Color(red: 0.46, green: 0.34, blue: 0.56),
                controlFill: Color(red: 0.92, green: 0.93, blue: 0.95),
                controlFillPressed: Color(red: 0.88, green: 0.90, blue: 0.93),
                controlBorder: Color.black.opacity(0.12),
                chipFill: Color(red: 0.95, green: 0.96, blue: 0.98),
                chipSelectedFill: Color(red: 0.88, green: 0.90, blue: 0.94),
                chipBorder: Color.black.opacity(0.12),
                feedbackSuccess: Color(red: 0.30, green: 0.44, blue: 0.40),
                feedbackMiss: Color(red: 0.62, green: 0.36, blue: 0.38),
                staffLineColor: Color.black.opacity(0.22),
                clefOpacity: 0.30
            )
        case .mono:
            return ThemePalette(
                backgroundTop: Color(red: 0.98, green: 0.98, blue: 0.98),
                backgroundBottom: Color(red: 0.92, green: 0.92, blue: 0.92),
                cardBackground: Color.white,
                cardBorder: Color.black.opacity(0.12),
                cardShadow: Color.black.opacity(0.10),
                textPrimary: Color.black.opacity(0.88),
                textSecondary: Color.black.opacity(0.52),
                accent: Color.black.opacity(0.90),
                accentPressed: Color.black,
                lowAccent: Color.black.opacity(0.70),
                midAccent: Color.black.opacity(0.55),
                highAccent: Color.black.opacity(0.40),
                controlFill: Color.black.opacity(0.06),
                controlFillPressed: Color.black.opacity(0.10),
                controlBorder: Color.black.opacity(0.12),
                chipFill: Color.black.opacity(0.05),
                chipSelectedFill: Color.black.opacity(0.12),
                chipBorder: Color.black.opacity(0.12),
                feedbackSuccess: Color.black.opacity(0.90),
                feedbackMiss: Color.black.opacity(0.55),
                staffLineColor: Color.black.opacity(0.25),
                clefOpacity: 0.30
            )
        }
    }

    static var current: AppTheme {
        let raw = UserDefaults.standard.string(forKey: AppSettingsKeys.appTheme) ?? AppTheme.zen.rawValue
        return AppTheme(rawValue: raw) ?? .zen
    }
}

struct ThemePalette {
    let backgroundTop: Color
    let backgroundBottom: Color
    let cardBackground: Color
    let cardBorder: Color
    let cardShadow: Color
    let textPrimary: Color
    let textSecondary: Color
    let accent: Color
    let accentPressed: Color
    let lowAccent: Color
    let midAccent: Color
    let highAccent: Color
    let controlFill: Color
    let controlFillPressed: Color
    let controlBorder: Color
    let chipFill: Color
    let chipSelectedFill: Color
    let chipBorder: Color
    let feedbackSuccess: Color
    let feedbackMiss: Color
    let staffLineColor: Color
    let clefOpacity: Double
}
