import SwiftUI

struct AppSettingsSheetView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(AppSettingsKeys.soundEffectsEnabled) private var soundEnabled: Bool = true
    @AppStorage(AppSettingsKeys.appLanguage) private var appLanguageRaw: String = AppLanguage.system.rawValue
    @AppStorage(AppSettingsKeys.showNoteName) private var showNoteName: Bool = false
    @AppStorage(AppSettingsKeys.showWrongNoteName) private var showWrongNoteName: Bool = true
    // Feedback note-name display removed per product direction.
    @AppStorage(AppSettingsKeys.useColoredKeys) private var useColoredKeys: Bool = true
    @AppStorage(AppSettingsKeys.useColoredNotes) private var useColoredNotes: Bool = false
    @AppStorage(AppSettingsKeys.noteDisplayRhythmMode) private var noteDisplayRhythmModeRaw: String = NoteDisplayRhythmMode.quarter.rawValue

    var body: some View {
        NavigationView {
            ScrollView {
                AppSettingsCard(
                    soundEnabled: $soundEnabled,
                    appLanguageRaw: $appLanguageRaw,
                    showNoteName: $showNoteName,
                    showWrongNoteName: $showWrongNoteName,
                    // showJudgementNoteName removed
                    useColoredKeys: $useColoredKeys,
                    useColoredNotes: $useColoredNotes,
                    noteDisplayRhythmModeRaw: $noteDisplayRhythmModeRaw
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
