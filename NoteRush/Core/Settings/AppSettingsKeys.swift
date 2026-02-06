import Foundation
import SwiftUI

enum AppSettingsKeys {
    static let soundEffectsEnabled = "soundEffectsEnabled"
    static let showCorrectHint = "showCorrectHint"
    static let appLanguage = "appLanguage"
    static let appTheme = "appTheme"
    static let appearanceMode = "appearanceMode"
    static let staffClefMode = "staffClefMode"
    static let showNoteName = "showNoteName"
    static let showJudgementNoteName = "showJudgementNoteName"
    static let freePracticeClefMode = "freePracticeClefMode"
    static let useColoredKeys = "useColoredKeys"
    static let useColoredNotes = "useColoredNotes"
    static let noteDisplayRhythmMode = "noteDisplayRhythmMode"
    static let microphoneInputEnabled = "microphoneInputEnabled" // legacy
    static let midiInputEnabled = "midiInputEnabled" // legacy
    static let inputMode = "inputMode"
}

enum InputMode: String, CaseIterable, Identifiable {
    case buttons
    case microphone
    case midi

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .buttons: return "InputMode.Buttons"
        case .microphone: return "InputMode.Microphone"
        case .midi: return "InputMode.MIDI"
        }
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .system: return "AppearanceMode.System"
        case .light: return "AppearanceMode.Light"
        case .dark: return "AppearanceMode.Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

