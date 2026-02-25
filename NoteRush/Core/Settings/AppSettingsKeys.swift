import Foundation
import SwiftUI

enum AppSettingsKeys {
    static let soundEffectsEnabled = "soundEffectsEnabled"
    static let showCorrectHint = "showCorrectHint"
    static let appLanguage = "appLanguage"
    static let appTheme = "appTheme"
    static let staffClefMode = "staffClefMode"
    static let showNoteName = "showNoteName"
    // New: show the correct note name after a wrong answer.
    static let showWrongNoteName = "showWrongNoteName"
    static let showJudgementNoteName = "showJudgementNoteName"
    static let freePracticeClefMode = "freePracticeClefMode"
    static let useColoredKeys = "useColoredKeys"
    static let useColoredNotes = "useColoredNotes"
    static let noteDisplayRhythmMode = "noteDisplayRhythmMode"
    static let noteNamingMode = "noteNamingMode"
    static let microphoneInputEnabled = "microphoneInputEnabled" // legacy
    static let midiInputEnabled = "midiInputEnabled" // legacy
    static let inputMode = "inputMode"

    // MARK: - Records (cumulative stats)
    static let recordsTotalAnswered = "recordsTotalAnswered"
    static let recordsTotalCorrect = "recordsTotalCorrect"
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


