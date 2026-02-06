import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    /// 森林（柔和的绿色系）
    case zen
    /// 干净（极简、清爽、中性）
    case mist
    /// 奶茶（温暖的米色系）
    case sand
    /// 水（清透的蓝/青色系）
    case ink

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .zen:
            return "森林"
        case .mist:
            return "干净"
        case .sand:
            return "奶茶"
        case .ink:
            return "水"
        }
    }

    var palette: ThemePalette {
        switch self {
        case .zen: // 森林
            return ThemePalette(
                backgroundTop: Color(red: 0.95, green: 0.97, blue: 0.94),
                backgroundBottom: Color(red: 0.88, green: 0.94, blue: 0.89),
                cardBackground: Color(red: 0.99, green: 0.99, blue: 0.98),
                cardBorder: Color.black.opacity(0.07),
                cardShadow: Color.black.opacity(0.07),
                textPrimary: Color(red: 0.16, green: 0.18, blue: 0.16),
                textSecondary: Color(red: 0.40, green: 0.45, blue: 0.40),
                accent: Color(red: 0.20, green: 0.52, blue: 0.34),
                accentPressed: Color(red: 0.16, green: 0.44, blue: 0.29),
                lowAccent: Color(red: 0.16, green: 0.44, blue: 0.32),
                midAccent: Color(red: 0.32, green: 0.62, blue: 0.40),
                highAccent: Color(red: 0.62, green: 0.54, blue: 0.34),
                controlFill: Color(red: 0.93, green: 0.95, blue: 0.92),
                controlFillPressed: Color(red: 0.89, green: 0.92, blue: 0.88),
                controlBorder: Color.black.opacity(0.10),
                chipFill: Color(red: 0.94, green: 0.96, blue: 0.93),
                chipSelectedFill: Color(red: 0.86, green: 0.92, blue: 0.87),
                chipBorder: Color.black.opacity(0.10),
                feedbackSuccess: Color(red: 0.20, green: 0.52, blue: 0.34),
                feedbackMiss: Color(red: 0.78, green: 0.42, blue: 0.36),
                staffLineColor: Color.black.opacity(0.20),
                clefOpacity: 0.30
            )
        case .mist: // 干净
            return ThemePalette(
                backgroundTop: Color(red: 0.98, green: 0.98, blue: 0.99),
                backgroundBottom: Color(red: 0.93, green: 0.95, blue: 0.97),
                cardBackground: Color(red: 1.00, green: 1.00, blue: 1.00),
                cardBorder: Color.black.opacity(0.06),
                cardShadow: Color.black.opacity(0.06),
                textPrimary: Color(red: 0.18, green: 0.20, blue: 0.22),
                textSecondary: Color(red: 0.44, green: 0.48, blue: 0.52),
                accent: Color(red: 0.22, green: 0.52, blue: 0.60),
                accentPressed: Color(red: 0.18, green: 0.44, blue: 0.52),
                lowAccent: Color(red: 0.28, green: 0.50, blue: 0.72),
                midAccent: Color(red: 0.20, green: 0.64, blue: 0.62),
                highAccent: Color(red: 0.62, green: 0.46, blue: 0.74),
                controlFill: Color(red: 0.94, green: 0.96, blue: 0.97),
                controlFillPressed: Color(red: 0.90, green: 0.93, blue: 0.95),
                controlBorder: Color.black.opacity(0.09),
                chipFill: Color(red: 0.95, green: 0.97, blue: 0.98),
                chipSelectedFill: Color(red: 0.88, green: 0.94, blue: 0.97),
                chipBorder: Color.black.opacity(0.09),
                feedbackSuccess: Color(red: 0.22, green: 0.52, blue: 0.60),
                feedbackMiss: Color(red: 0.78, green: 0.42, blue: 0.40),
                staffLineColor: Color.black.opacity(0.20),
                clefOpacity: 0.28
            )
        case .sand: // 奶茶
            return ThemePalette(
                backgroundTop: Color(red: 0.99, green: 0.96, blue: 0.92),
                backgroundBottom: Color(red: 0.95, green: 0.92, blue: 0.88),
                cardBackground: Color(red: 1.00, green: 0.99, blue: 0.97),
                cardBorder: Color.black.opacity(0.07),
                cardShadow: Color.black.opacity(0.07),
                textPrimary: Color(red: 0.22, green: 0.18, blue: 0.14),
                textSecondary: Color(red: 0.48, green: 0.40, blue: 0.34),
                accent: Color(red: 0.70, green: 0.46, blue: 0.30),
                accentPressed: Color(red: 0.60, green: 0.40, blue: 0.26),
                lowAccent: Color(red: 0.66, green: 0.40, blue: 0.28),
                midAccent: Color(red: 0.54, green: 0.56, blue: 0.36),
                highAccent: Color(red: 0.80, green: 0.58, blue: 0.42),
                controlFill: Color(red: 0.95, green: 0.92, blue: 0.88),
                controlFillPressed: Color(red: 0.92, green: 0.88, blue: 0.84),
                controlBorder: Color.black.opacity(0.11),
                chipFill: Color(red: 0.96, green: 0.93, blue: 0.90),
                chipSelectedFill: Color(red: 0.93, green: 0.88, blue: 0.84),
                chipBorder: Color.black.opacity(0.11),
                feedbackSuccess: Color(red: 0.54, green: 0.56, blue: 0.36),
                feedbackMiss: Color(red: 0.78, green: 0.42, blue: 0.36),
                staffLineColor: Color.black.opacity(0.22),
                clefOpacity: 0.30
            )
        case .ink: // 水
            return ThemePalette(
                backgroundTop: Color(red: 0.94, green: 0.97, blue: 0.99),
                backgroundBottom: Color(red: 0.88, green: 0.94, blue: 0.98),
                cardBackground: Color(red: 0.99, green: 1.00, blue: 1.00),
                cardBorder: Color.black.opacity(0.07),
                cardShadow: Color.black.opacity(0.07),
                textPrimary: Color(red: 0.16, green: 0.20, blue: 0.24),
                textSecondary: Color(red: 0.40, green: 0.48, blue: 0.54),
                accent: Color(red: 0.18, green: 0.56, blue: 0.72),
                accentPressed: Color(red: 0.14, green: 0.48, blue: 0.62),
                lowAccent: Color(red: 0.22, green: 0.54, blue: 0.82),
                midAccent: Color(red: 0.20, green: 0.68, blue: 0.66),
                highAccent: Color(red: 0.52, green: 0.50, blue: 0.78),
                controlFill: Color(red: 0.92, green: 0.96, blue: 0.98),
                controlFillPressed: Color(red: 0.88, green: 0.93, blue: 0.96),
                controlBorder: Color.black.opacity(0.10),
                chipFill: Color(red: 0.94, green: 0.97, blue: 0.99),
                chipSelectedFill: Color(red: 0.86, green: 0.93, blue: 0.98),
                chipBorder: Color.black.opacity(0.10),
                feedbackSuccess: Color(red: 0.18, green: 0.56, blue: 0.72),
                feedbackMiss: Color(red: 0.78, green: 0.42, blue: 0.40),
                staffLineColor: Color.black.opacity(0.20),
                clefOpacity: 0.28
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
