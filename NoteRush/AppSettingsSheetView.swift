import SwiftUI

struct AppSettingsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppSettingsKeys.soundEffectsEnabled) private var soundEnabled: Bool = true
    @AppStorage(AppSettingsKeys.showCorrectHint) private var showCorrectHint: Bool = false
    @AppStorage(AppSettingsKeys.appLanguage) private var appLanguageRaw: String = AppLanguage.system.rawValue
    @AppStorage(AppSettingsKeys.appTheme) private var appThemeRaw: String = AppTheme.zen.rawValue
    @AppStorage(AppSettingsKeys.showNoteName) private var showNoteName: Bool = false
    @AppStorage(AppSettingsKeys.showJudgementNoteName) private var showJudgementNoteName: Bool = false
    @AppStorage(AppSettingsKeys.useColoredKeys) private var useColoredKeys: Bool = true
    @AppStorage(AppSettingsKeys.useColoredNotes) private var useColoredNotes: Bool = false
    @AppStorage(AppSettingsKeys.noteDisplayRhythmMode) private var noteDisplayRhythmModeRaw: String = NoteDisplayRhythmMode.quarter.rawValue
    @AppStorage(AppSettingsKeys.microphoneInputEnabled) private var microphoneInputEnabled: Bool = false
    @AppStorage(AppSettingsKeys.midiInputEnabled) private var midiInputEnabled: Bool = false

    var body: some View {
        NavigationView {
            ScrollView {
                AppSettingsCard(
                    soundEnabled: $soundEnabled,
                    showCorrectHint: $showCorrectHint,
                    appLanguageRaw: $appLanguageRaw,
                    appThemeRaw: $appThemeRaw,
                    showNoteName: $showNoteName,
                    showJudgementNoteName: $showJudgementNoteName,
                    useColoredKeys: $useColoredKeys,
                    useColoredNotes: $useColoredNotes,
                    noteDisplayRhythmModeRaw: $noteDisplayRhythmModeRaw,
                    microphoneInputEnabled: $microphoneInputEnabled,
                    midiInputEnabled: $midiInputEnabled
                )
                .padding(16)
            }
            .background(CuteTheme.backgroundTop.opacity(0.12))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
