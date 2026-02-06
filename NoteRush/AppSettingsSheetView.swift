import SwiftUI

struct AppSettingsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var themeRefreshToken: UUID = UUID()

    @AppStorage(AppSettingsKeys.soundEffectsEnabled) private var soundEnabled: Bool = true
    @AppStorage(AppSettingsKeys.showCorrectHint) private var showCorrectHint: Bool = false
    @AppStorage(AppSettingsKeys.appLanguage) private var appLanguageRaw: String = AppLanguage.system.rawValue
    @AppStorage(AppSettingsKeys.appTheme) private var appThemeRaw: String = AppTheme.zen.rawValue
    @AppStorage(AppSettingsKeys.appearanceMode) private var appearanceModeRaw: String = AppearanceMode.system.rawValue
    @AppStorage(AppSettingsKeys.showNoteName) private var showNoteName: Bool = false
    @AppStorage(AppSettingsKeys.showJudgementNoteName) private var showJudgementNoteName: Bool = false
    @AppStorage(AppSettingsKeys.useColoredKeys) private var useColoredKeys: Bool = true
    @AppStorage(AppSettingsKeys.useColoredNotes) private var useColoredNotes: Bool = false
    @AppStorage(AppSettingsKeys.noteDisplayRhythmMode) private var noteDisplayRhythmModeRaw: String = NoteDisplayRhythmMode.quarter.rawValue
    @AppStorage(AppSettingsKeys.microphoneInputEnabled) private var microphoneInputEnabled: Bool = false
    @AppStorage(AppSettingsKeys.midiInputEnabled) private var midiInputEnabled: Bool = false
    @AppStorage(AppSettingsKeys.inputMode) private var inputModeRaw: String = InputMode.buttons.rawValue

    var body: some View {
        NavigationView {
            ScrollView {
                AppSettingsCard(
                    soundEnabled: $soundEnabled,
                    showCorrectHint: $showCorrectHint,
                    appLanguageRaw: $appLanguageRaw,
                    appThemeRaw: $appThemeRaw,
                    appearanceModeRaw: $appearanceModeRaw,
                    showNoteName: $showNoteName,
                    showJudgementNoteName: $showJudgementNoteName,
                    useColoredKeys: $useColoredKeys,
                    useColoredNotes: $useColoredNotes,
                    noteDisplayRhythmModeRaw: $noteDisplayRhythmModeRaw,
                    microphoneInputEnabled: $microphoneInputEnabled,
                    midiInputEnabled: $midiInputEnabled,
                    inputModeRaw: $inputModeRaw
                )
                .padding(16)
            }
            // Refresh the sheet immediately when theme changes, without dismissing it.
            .id(themeRefreshToken)
            .background(CuteTheme.backgroundTop.opacity(0.12))
            .onChange(of: appThemeRaw) { newValue in
                // Ensure the theme is persisted immediately (and trigger a view refresh).
                UserDefaults.standard.set(newValue, forKey: AppSettingsKeys.appTheme)
                themeRefreshToken = UUID()
            }
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
