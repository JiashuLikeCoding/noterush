import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    /// 森林（柔和的绿色系）
    case zen
    /// 奶茶（温暖的米色系）
    case sand

    /// 雾紫 / 薰衣草（灰紫 + 米白）
    case lavender
    /// 石墨 / 冷灰（冷灰白 + 石墨点缀）
    case graphite

    /// 经典配色（经典黑白 + iOS 蓝）
    case classic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .zen:
            return "森林"
        case .sand:
            return "奶茶"
        case .lavender:
            return "雾紫"
        case .graphite:
            return "石墨"
        case .classic:
            return "经典"
        }
    }

    var palette: ThemePalette {
        switch self {
        case .zen: // 森林（无印：偏灰的苔绿/鼠尾草绿）
            return ThemePalette(
                backgroundTop: Color(red: 0.96, green: 0.97, blue: 0.95),
                backgroundBottom: Color(red: 0.92, green: 0.94, blue: 0.91),
                cardBackground: Color(red: 0.99, green: 0.99, blue: 0.98),
                cardBorder: Color.black.opacity(0.06),
                cardShadow: Color.black.opacity(0.06),
                textPrimary: Color(red: 0.18, green: 0.19, blue: 0.17),
                textSecondary: Color(red: 0.46, green: 0.48, blue: 0.45),
                accent: Color(red: 0.34, green: 0.48, blue: 0.38),
                accentPressed: Color(red: 0.28, green: 0.42, blue: 0.33),
                lowAccent: Color(red: 0.40, green: 0.52, blue: 0.42),
                midAccent: Color(red: 0.46, green: 0.58, blue: 0.47),
                highAccent: Color(red: 0.56, green: 0.54, blue: 0.40),
                controlFill: Color(red: 0.94, green: 0.95, blue: 0.93),
                controlFillPressed: Color(red: 0.90, green: 0.92, blue: 0.89),
                controlBorder: Color.black.opacity(0.09),
                chipFill: Color(red: 0.95, green: 0.96, blue: 0.94),
                chipSelectedFill: Color(red: 0.90, green: 0.92, blue: 0.89),
                chipBorder: Color.black.opacity(0.09),
                feedbackSuccess: Color(red: 0.34, green: 0.48, blue: 0.38),
                feedbackMiss: Color(red: 0.64, green: 0.44, blue: 0.40),
                staffLineColor: Color.black.opacity(0.20),
                clefOpacity: 0.30
            )
        case .sand: // 奶茶（无印：灰米色 + 低饱和茶棕）
            return ThemePalette(
                backgroundTop: Color(red: 0.98, green: 0.96, blue: 0.93),
                backgroundBottom: Color(red: 0.94, green: 0.92, blue: 0.89),
                cardBackground: Color(red: 1.00, green: 0.99, blue: 0.97),
                cardBorder: Color.black.opacity(0.06),
                cardShadow: Color.black.opacity(0.06),
                textPrimary: Color(red: 0.22, green: 0.20, blue: 0.18),
                textSecondary: Color(red: 0.52, green: 0.48, blue: 0.44),
                accent: Color(red: 0.60, green: 0.48, blue: 0.38),
                accentPressed: Color(red: 0.54, green: 0.42, blue: 0.34),
                lowAccent: Color(red: 0.58, green: 0.46, blue: 0.36),
                midAccent: Color(red: 0.56, green: 0.54, blue: 0.44),
                highAccent: Color(red: 0.62, green: 0.56, blue: 0.46),
                controlFill: Color(red: 0.95, green: 0.93, blue: 0.90),
                controlFillPressed: Color(red: 0.91, green: 0.89, blue: 0.86),
                controlBorder: Color.black.opacity(0.10),
                chipFill: Color(red: 0.96, green: 0.94, blue: 0.91),
                chipSelectedFill: Color(red: 0.92, green: 0.88, blue: 0.85),
                chipBorder: Color.black.opacity(0.10),
                feedbackSuccess: Color(red: 0.56, green: 0.54, blue: 0.44),
                feedbackMiss: Color(red: 0.64, green: 0.44, blue: 0.40),
                staffLineColor: Color.black.opacity(0.22),
                clefOpacity: 0.30
            )

        case .lavender: // 雾紫 / 薰衣草
            return ThemePalette(
                backgroundTop: Color(red: 0.97, green: 0.96, blue: 0.98),
                backgroundBottom: Color(red: 0.93, green: 0.92, blue: 0.95),
                cardBackground: Color(red: 1.00, green: 0.99, blue: 1.00),
                cardBorder: Color.black.opacity(0.06),
                cardShadow: Color.black.opacity(0.06),
                textPrimary: Color(red: 0.21, green: 0.20, blue: 0.24),
                textSecondary: Color(red: 0.54, green: 0.52, blue: 0.58),
                accent: Color(red: 0.52, green: 0.46, blue: 0.62),
                accentPressed: Color(red: 0.46, green: 0.40, blue: 0.56),
                lowAccent: Color(red: 0.56, green: 0.50, blue: 0.66),
                midAccent: Color(red: 0.58, green: 0.56, blue: 0.70),
                highAccent: Color(red: 0.62, green: 0.52, blue: 0.58),
                controlFill: Color(red: 0.96, green: 0.95, blue: 0.97),
                controlFillPressed: Color(red: 0.92, green: 0.91, blue: 0.94),
                controlBorder: Color.black.opacity(0.09),
                chipFill: Color(red: 0.97, green: 0.96, blue: 0.98),
                chipSelectedFill: Color(red: 0.93, green: 0.92, blue: 0.96),
                chipBorder: Color.black.opacity(0.09),
                feedbackSuccess: Color(red: 0.52, green: 0.46, blue: 0.62),
                feedbackMiss: Color(red: 0.64, green: 0.44, blue: 0.48),
                staffLineColor: Color.black.opacity(0.20),
                clefOpacity: 0.28
            )

        case .graphite: // 石墨 / 冷灰
            return ThemePalette(
                backgroundTop: Color(red: 0.98, green: 0.98, blue: 0.98),
                backgroundBottom: Color(red: 0.93, green: 0.94, blue: 0.95),
                cardBackground: Color(red: 1.00, green: 1.00, blue: 1.00),
                cardBorder: Color.black.opacity(0.07),
                cardShadow: Color.black.opacity(0.07),
                textPrimary: Color(red: 0.18, green: 0.19, blue: 0.20),
                textSecondary: Color(red: 0.50, green: 0.52, blue: 0.54),
                accent: Color(red: 0.36, green: 0.38, blue: 0.42),
                accentPressed: Color(red: 0.30, green: 0.32, blue: 0.36),
                lowAccent: Color(red: 0.44, green: 0.46, blue: 0.50),
                midAccent: Color(red: 0.40, green: 0.44, blue: 0.48),
                highAccent: Color(red: 0.54, green: 0.50, blue: 0.48),
                controlFill: Color(red: 0.95, green: 0.96, blue: 0.97),
                controlFillPressed: Color(red: 0.91, green: 0.92, blue: 0.94),
                controlBorder: Color.black.opacity(0.10),
                chipFill: Color(red: 0.96, green: 0.97, blue: 0.98),
                chipSelectedFill: Color(red: 0.91, green: 0.93, blue: 0.95),
                chipBorder: Color.black.opacity(0.10),
                feedbackSuccess: Color(red: 0.36, green: 0.38, blue: 0.42),
                feedbackMiss: Color(red: 0.60, green: 0.44, blue: 0.40),
                staffLineColor: Color.black.opacity(0.22),
                clefOpacity: 0.28
            )

        case .classic: // 经典（黑白 + iOS 蓝）
            return ThemePalette(
                backgroundTop: Color(red: 0.98, green: 0.98, blue: 0.98),
                backgroundBottom: Color(red: 0.94, green: 0.94, blue: 0.95),
                cardBackground: Color(red: 1.00, green: 1.00, blue: 1.00),
                cardBorder: Color.black.opacity(0.08),
                cardShadow: Color.black.opacity(0.08),
                textPrimary: Color.black.opacity(0.88),
                textSecondary: Color.black.opacity(0.55),
                accent: Color(red: 0.00, green: 0.48, blue: 1.00),
                accentPressed: Color(red: 0.00, green: 0.40, blue: 0.86),
                lowAccent: Color(red: 0.00, green: 0.48, blue: 1.00),
                midAccent: Color(red: 0.32, green: 0.72, blue: 0.66),
                highAccent: Color(red: 0.56, green: 0.36, blue: 0.96),
                controlFill: Color.black.opacity(0.06),
                controlFillPressed: Color.black.opacity(0.10),
                controlBorder: Color.black.opacity(0.12),
                chipFill: Color.black.opacity(0.05),
                chipSelectedFill: Color.black.opacity(0.12),
                chipBorder: Color.black.opacity(0.12),
                feedbackSuccess: Color(red: 0.00, green: 0.48, blue: 1.00),
                feedbackMiss: Color(red: 0.80, green: 0.28, blue: 0.28),
                staffLineColor: Color.black.opacity(0.22),
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
