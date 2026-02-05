import SwiftUI

enum SelectionTab: String, CaseIterable, Identifiable {
    case practiceNotes = "Free Practice"
    case songs = "Songs"
    case levels = "Level"

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .practiceNotes:
            return "Tab.PracticeNotes"
        case .songs:
            return "Tab.Songs"
        case .levels:
            return "Tab.Levels"
        }
    }
}

struct SelectionView: View {
    @Binding var bpm: Double
    @Binding var namingMode: NoteNamingMode
    @Binding var rhythm: NoteRhythm
    @Binding var selectedLetters: Set<NoteLetter>
    @Binding var selectedLevel: PracticeLevel?
    @Binding var selectedSong: SongTemplate?
    @Binding var songClefModes: [UUID: StaffClefMode]
    let onStartPractice: () -> Void
    let onStartSong: (SongTemplate, Set<NoteLetter>, StaffClefMode) -> Void
    @State private var activeTab: SelectionTab = .practiceNotes
    @State private var showingSettings: Bool = false

    @AppStorage(AppSettingsKeys.soundEffectsEnabled) private var soundEnabled: Bool = true
    @AppStorage(AppSettingsKeys.showCorrectHint) private var showCorrectHint: Bool = false
    @AppStorage(AppSettingsKeys.appLanguage) private var appLanguageRaw: String = AppLanguage.system.rawValue
    @AppStorage(AppSettingsKeys.appTheme) private var appThemeRaw: String = AppTheme.zen.rawValue
    @AppStorage(AppSettingsKeys.staffClefMode) private var staffClefModeRaw: String = StaffClefMode.treble.rawValue
    @AppStorage(AppSettingsKeys.showNoteName) private var showNoteName: Bool = false
    @AppStorage(AppSettingsKeys.showJudgementNoteName) private var showJudgementNoteName: Bool = false
    @AppStorage(AppSettingsKeys.freePracticeClefMode) private var freePracticeClefModeRaw: String = StaffClefMode.treble.rawValue
    @AppStorage(AppSettingsKeys.useColoredKeys) private var useColoredKeys: Bool = true
    @AppStorage(AppSettingsKeys.useColoredNotes) private var useColoredNotes: Bool = false
    @AppStorage(AppSettingsKeys.noteDisplayRhythmMode) private var noteDisplayRhythmModeRaw: String = NoteDisplayRhythmMode.quarter.rawValue
    @AppStorage(AppSettingsKeys.microphoneInputEnabled) private var microphoneInputEnabled: Bool = false

    @State private var songTargetLetters: [UUID: Set<NoteLetter>] = [:]

    var body: some View {
        VStack(spacing: 16) {
            SelectionHeaderView(
                showingSettings: showingSettings,
                onToggleSettings: { showingSettings.toggle() }
            )

            if !showingSettings {
                SelectionTabBar(activeTab: $activeTab)
                    .padding(.horizontal, 20)
            }

            ScrollView {
                VStack(spacing: 18) {
                    if !showingSettings {
                        switch activeTab {
                        case .practiceNotes:
                            PracticeNotesCard(
                                namingMode: namingMode,
                                selectedLetters: $selectedLetters,
                                selectedLevel: $selectedLevel,
                                freePracticeClefModeRaw: $freePracticeClefModeRaw,
                                onStart: onStartPractice
                            )
                        case .songs:
                            SongSelectionCard(
                                namingMode: namingMode,
                                selectedSong: $selectedSong,
                                defaultClefMode: StaffClefMode(rawValue: staffClefModeRaw) ?? .treble,
                                songClefModes: $songClefModes,
                                songTargetLetters: $songTargetLetters,
                                onStart: onStartSong
                            )
                        case .levels:
                            LevelSelectionCard(
                                selectedLetters: $selectedLetters,
                                selectedLevel: $selectedLevel,
                                selectedRhythm: $rhythm,
                                onStart: { level in
                                    selectedLevel = level
                                    selectedLetters = level.letters
                                    onStartPractice()
                                }
                            )
                        }
                    } else {
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
                            microphoneInputEnabled: $microphoneInputEnabled
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
        .padding(.top, 16)
        .zenBackground()
    }
}

struct SelectionTabBar: View {
    @Binding var activeTab: SelectionTab

    var body: some View {
        HStack(spacing: 12) {
            ForEach(SelectionTab.allCases) { tab in
                Button(action: { activeTab = tab }) {
                    VStack(spacing: 6) {
                        Text(tab.titleKey)
                            .font(.custom("AvenirNext-DemiBold", size: CuteTheme.FontSize.body))
                            .foregroundColor(activeTab == tab ? CuteTheme.textPrimary : CuteTheme.textSecondary)
                        Rectangle()
                            .fill(activeTab == tab ? CuteTheme.accent : Color.clear)
                            .frame(height: 2)
                            .cornerRadius(1)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct SelectionHeaderView: View {
    let showingSettings: Bool
    let onToggleSettings: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(showingSettings ? "Settings" : "Session Setup")
                    .font(.custom("AvenirNext-DemiBold", size: CuteTheme.FontSize.title))
                    .foregroundColor(CuteTheme.textPrimary)
                Text(showingSettings ? "Shape the way you practice." : "Choose a path and begin quietly.")
                    .font(.custom("AvenirNext-Regular", size: CuteTheme.FontSize.caption))
                    .foregroundColor(CuteTheme.textSecondary)
            }
            Spacer()
            Button(action: onToggleSettings) {
                Image(systemName: showingSettings ? "xmark" : "gearshape")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(CuteTheme.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(CuteTheme.controlFill)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(CuteTheme.controlBorder, lineWidth: 1)
                    )
            }
            .accessibilityLabel(showingSettings ? "Close settings" : "Open settings")
        }
        .padding(.horizontal, 20)
    }
}

struct ZenCardHeader: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom("AvenirNext-DemiBold", size: CuteTheme.FontSize.section))
                    .foregroundColor(CuteTheme.textPrimary)
                Text(subtitle)
                    .font(.custom("AvenirNext-Regular", size: CuteTheme.FontSize.caption))
                    .foregroundColor(CuteTheme.textSecondary)
            }
            Spacer()
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(CuteTheme.accent)
                .frame(width: 32, height: 32)
                .background(CuteTheme.controlFill)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(CuteTheme.controlBorder, lineWidth: 1)
                )
        }
    }
}

struct ZenDivider: View {
    var body: some View {
        Rectangle()
            .fill(CuteTheme.cardBorder)
            .frame(height: 1)
    }
}

struct ZenMetaTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.custom("AvenirNext-Regular", size: 11))
            .foregroundColor(CuteTheme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(CuteTheme.controlFill)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(CuteTheme.controlBorder, lineWidth: 1)
            )
    }
}

struct ZenClefPicker: View {
    @Binding var selection: StaffClefMode

    var body: some View {
        HStack(spacing: 6) {
            ForEach(StaffClefMode.allCases) { mode in
                Button(action: { selection = mode }) {
                    Text(mode.titleKey)
                        .font(.custom("AvenirNext-DemiBold", size: 10))
                        .foregroundColor(selection == mode ? .white : CuteTheme.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(selection == mode ? CuteTheme.accent : CuteTheme.controlFill)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(CuteTheme.cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(CuteTheme.controlBorder, lineWidth: 1)
        )
    }
}

struct ZenLevelTabBar: View {
    let levels: [Int]
    let selectedLevel: Int?
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(levels, id: \.self) { level in
                Button(action: { onSelect(level) }) {
                    VStack(spacing: 8) {
                        Text("L\(level)")
                            .font(.custom("AvenirNext-DemiBold", size: CuteTheme.FontSize.section))
                            .foregroundColor(selectedLevel == level ? CuteTheme.textPrimary : CuteTheme.textSecondary)
                            .frame(maxWidth: .infinity)

                        Rectangle()
                            .fill(selectedLevel == level ? CuteTheme.accent : Color.clear)
                            .frame(height: 3)
                            .cornerRadius(1.5)
                    }
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 2)
    }
}

struct ZenActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("AvenirNext-DemiBold", size: CuteTheme.FontSize.caption))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(configuration.isPressed ? CuteTheme.accentPressed : CuteTheme.accent)
            .cornerRadius(12)
    }
}

struct ZenLetterChip: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        Text(title)
            .font(.custom("AvenirNext-DemiBold", size: 12))
            .foregroundColor(isSelected ? .white : CuteTheme.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 32)
            .background(isSelected ? CuteTheme.accent : CuteTheme.controlFill)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? CuteTheme.accent.opacity(0.3) : CuteTheme.controlBorder, lineWidth: 1)
            )
    }
}

struct LanguagePickerSheet: View {
    let languages: [AppLanguage]
    let selected: AppLanguage
    let onSelect: (AppLanguage) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.clear.zenBackground()

            VStack(spacing: 16) {
                HStack {
                    Text("Language")
                        .font(.custom("AvenirNext-DemiBold", size: CuteTheme.FontSize.section))
                        .foregroundColor(CuteTheme.textPrimary)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(CuteTheme.textPrimary)
                            .frame(width: 30, height: 30)
                            .background(CuteTheme.controlFill)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(CuteTheme.controlBorder, lineWidth: 1)
                            )
                    }
                }

                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(languages) { language in
                            Button(action: { onSelect(language) }) {
                                HStack(spacing: 12) {
                                    Text(language.flag)
                                        .font(.system(size: 18))
                                    Text(language.nativeName)
                                        .font(.custom("AvenirNext-DemiBold", size: CuteTheme.FontSize.body))
                                        .foregroundColor(CuteTheme.textPrimary)
                                    Spacer()
                                    if selected == language {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(CuteTheme.accent)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .frame(minHeight: 44)
                                .background(CuteTheme.cardBackground)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(CuteTheme.cardBorder, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 10)
                }
            }
            .padding(18)
            .background(CuteTheme.cardBackground)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(CuteTheme.cardBorder, lineWidth: 1)
            )
            .padding(20)
        }
        .presentationDetents([.medium, .large])
    }
}

struct ThemePicker: View {
    @Binding var selectedRaw: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(AppTheme.allCases) { theme in
                    Button(action: { selectedRaw = theme.rawValue }) {
                        ThemeSwatch(theme: theme, isSelected: selectedRaw == theme.rawValue)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

struct ThemeSwatch: View {
    let theme: AppTheme
    let isSelected: Bool

    var body: some View {
        let palette = theme.palette

        VStack(spacing: 6) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [palette.backgroundTop, palette.backgroundBottom]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? palette.accent : palette.cardBorder, lineWidth: isSelected ? 2 : 1)

                HStack(spacing: 6) {
                    Circle()
                        .fill(palette.accent)
                        .frame(width: 10, height: 10)
                    Circle()
                        .fill(palette.lowAccent)
                        .frame(width: 8, height: 8)
                    Circle()
                        .fill(palette.highAccent)
                        .frame(width: 8, height: 8)
                }
                .padding(8)
            }
            .frame(width: 96, height: 60)

            Text(theme.displayName)
                .font(.custom("AvenirNext-DemiBold", size: 11))
                .foregroundColor(CuteTheme.textPrimary)
        }
    }
}

struct AppSettingsCard: View {
    @Binding var soundEnabled: Bool
    @Binding var showCorrectHint: Bool
    @Binding var appLanguageRaw: String
    @Binding var appThemeRaw: String
    @Binding var showNoteName: Bool
    @Binding var showJudgementNoteName: Bool
    @Binding var useColoredKeys: Bool
    @Binding var useColoredNotes: Bool
    @Binding var noteDisplayRhythmModeRaw: String
    @Binding var microphoneInputEnabled: Bool
    @State private var showingLanguagePicker: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("App Settings")
                .font(.system(size: CuteTheme.FontSize.section, weight: .bold, design: .rounded))
                .foregroundColor(CuteTheme.textPrimary)

            Toggle("Sound Effects", isOn: $soundEnabled)
                .tint(CuteTheme.accent)

            Toggle("Show Correct Answer on Miss", isOn: $showCorrectHint)
                .tint(CuteTheme.accent)

            Toggle("Show Note Name", isOn: $showNoteName)
                .tint(CuteTheme.accent)

            Toggle("Show Feedback Note Name", isOn: $showJudgementNoteName)
                .tint(CuteTheme.accent)

            Toggle("Color Answer Keys", isOn: $useColoredKeys)
                .tint(CuteTheme.accent)

            Toggle("Color Notes", isOn: $useColoredNotes)
                .tint(CuteTheme.accent)

            Toggle("Microphone Input", isOn: $microphoneInputEnabled)
                .tint(CuteTheme.accent)

            VStack(alignment: .leading, spacing: 8) {
                Text("Theme")
                    .font(.custom("AvenirNext-Regular", size: CuteTheme.FontSize.body))
                    .foregroundColor(CuteTheme.textSecondary)

                ThemePicker(selectedRaw: $appThemeRaw)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Note Display")
                    .font(.custom("AvenirNext-Regular", size: CuteTheme.FontSize.body))
                    .foregroundColor(CuteTheme.textSecondary)

                let modes = NoteDisplayRhythmMode.allCases
                HStack(spacing: 8) {
                    ForEach(modes) { mode in
                        Button(action: {
                            noteDisplayRhythmModeRaw = mode.rawValue
                        }) {
                            Text(mode.titleKey)
                                .font(.custom("AvenirNext-DemiBold", size: CuteTheme.FontSize.caption))
                                .foregroundColor(noteDisplayRhythmModeRaw == mode.rawValue ? .white : CuteTheme.textPrimary)
                                .frame(maxWidth: .infinity, minHeight: 32)
                                .background(noteDisplayRhythmModeRaw == mode.rawValue ? CuteTheme.accent : CuteTheme.controlFill)
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Language")
                    .font(.custom("AvenirNext-Regular", size: CuteTheme.FontSize.body))
                    .foregroundColor(CuteTheme.textSecondary)

                let languages = AppLanguage.allCases
                let selectedLanguage = AppLanguage(rawValue: appLanguageRaw) ?? .system

                Button(action: { showingLanguagePicker = true }) {
                    HStack(spacing: 10) {
                        Text(selectedLanguage.flag)
                        Text(selectedLanguage.nativeName)
                            .font(.custom("AvenirNext-DemiBold", size: CuteTheme.FontSize.body))
                            .foregroundColor(CuteTheme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(CuteTheme.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 40)
                    .background(CuteTheme.controlFill)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(CuteTheme.controlBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showingLanguagePicker) {
                    LanguagePickerSheet(
                        languages: languages,
                        selected: selectedLanguage,
                        onSelect: { selection in
                            appLanguageRaw = selection.rawValue
                            showingLanguagePicker = false
                        }
                    )
                }
            }
        }
        .font(.system(size: CuteTheme.FontSize.body, weight: .medium, design: .rounded))
        .cardStyle()
    }
}

struct PracticeNotesCard: View {
    let namingMode: NoteNamingMode
    @Binding var selectedLetters: Set<NoteLetter>
    @Binding var selectedLevel: PracticeLevel?
    @Binding var freePracticeClefModeRaw: String
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZenCardHeader(
                title: "Free Practice",
                subtitle: "Pick clef and notes for a quiet drill.",
                symbol: "waveform.path"
            )

            ZenDivider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Clef.Title")
                    .font(.custom("AvenirNext-Regular", size: CuteTheme.FontSize.body))
                    .foregroundColor(CuteTheme.textSecondary)

                let clefBinding = Binding<StaffClefMode>(
                    get: { StaffClefMode(rawValue: freePracticeClefModeRaw) ?? .treble },
                    set: { newMode in
                        freePracticeClefModeRaw = newMode.rawValue
                        selectedLevel = nil
                    }
                )
                ZenClefPicker(selection: clefBinding)
            }

            ZenDivider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Training Notes")
                    .font(.custom("AvenirNext-Regular", size: CuteTheme.FontSize.body))
                    .foregroundColor(CuteTheme.textSecondary)

                let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(NoteLetter.allCases, id: \.self) { letter in
                        Button(action: { toggle(letter) }) {
                            ZenLetterChip(
                                title: letter.displayName(for: namingMode),
                                isSelected: selectedLetters.contains(letter)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if selectedLetters.isEmpty {
                Text("Select at least one note to start.")
                    .font(.custom("AvenirNext-Regular", size: CuteTheme.FontSize.caption))
                    .foregroundColor(.red.opacity(0.7))
            }

            Button(action: {
                selectedLevel = nil
                onStart()
            }) {
                Text("Start Practice")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(selectedLetters.isEmpty)
            .opacity(selectedLetters.isEmpty ? 0.5 : 1)
        }
        .cardStyle()
    }

    private func toggle(_ letter: NoteLetter) {
        if selectedLetters.contains(letter) {
            selectedLetters.remove(letter)
        } else {
            selectedLetters.insert(letter)
        }
        selectedLevel = nil
    }
}

struct LevelSelectionCard: View {
    @Binding var selectedLetters: Set<NoteLetter>
    @Binding var selectedLevel: PracticeLevel?
    @Binding var selectedRhythm: NoteRhythm
    let onStart: (PracticeLevel) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZenCardHeader(
                title: "Practice Levels",
                subtitle: "Structured paths for steady growth.",
                symbol: "list.bullet.rectangle"
            )

            VStack(spacing: 10) {
                ForEach(PracticeLevel.library) { level in
                    Button(action: { apply(level) }) {
                        LevelCardView(
                            level: level,
                            isSelected: selectedLevel?.id == level.id,
                            onStart: {
                                apply(level)
                                onStart(level)
                            }
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .cardStyle()
    }

    private func apply(_ level: PracticeLevel) {
        selectedLevel = level
        selectedLetters = level.letters
        selectedRhythm = level.rhythm
    }
}

struct LevelCardView: View {
    let level: PracticeLevel
    let isSelected: Bool
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(CuteTheme.controlFill)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(CuteTheme.controlBorder, lineWidth: 1)
                        )
                    Text("L\(level.id)")
                        .font(.custom("AvenirNext-DemiBold", size: 14))
                        .foregroundColor(CuteTheme.textPrimary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(level.title)
                        .font(.custom("AvenirNext-DemiBold", size: CuteTheme.FontSize.body))
                        .foregroundColor(CuteTheme.textPrimary)
                    Text(level.subtitle)
                        .font(.custom("AvenirNext-Regular", size: CuteTheme.FontSize.caption))
                        .foregroundColor(CuteTheme.textSecondary)
                }
                Spacer()
                ZenMetaTag(text: level.rhythm.displayName)
            }

            HStack(spacing: 6) {
                ForEach(level.rangeTags, id: \.self) { tag in
                    NoteChipView(
                        title: tag,
                        isSelected: false,
                        isDimmed: true
                    )
                }
            }

            Button(action: onStart) {
                Text("Start")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ZenActionButtonStyle())
        }
        .cardStyle()
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isSelected ? CuteTheme.accent : Color.clear, lineWidth: 2)
        )
    }
}

struct SongSelectionCard: View {
    let namingMode: NoteNamingMode
    @Binding var selectedSong: SongTemplate?
    let defaultClefMode: StaffClefMode
    @Binding var songClefModes: [UUID: StaffClefMode]
    @Binding var songTargetLetters: [UUID: Set<NoteLetter>]
    let onStart: (SongTemplate, Set<NoteLetter>, StaffClefMode) -> Void
    @State private var activeLevel: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZenCardHeader(
                title: "Songs",
                subtitle: "Pick a level and shape the clef.",
                symbol: "music.note.list"
            )

            let grouped = Dictionary(grouping: SongTemplate.library, by: \.level)
            let levels = grouped.keys.sorted()
            let resolvedLevel = activeLevel ?? levels.first

            ZenLevelTabBar(
                levels: levels,
                selectedLevel: resolvedLevel,
                onSelect: { activeLevel = $0 }
            )

            if let level = resolvedLevel {
                VStack(spacing: 12) {
                    ForEach(grouped[level] ?? []) { template in
                        let binding = Binding<Set<NoteLetter>>(
                            get: {
                                songTargetLetters[template.id] ?? template.allowedLetters
                            },
                            set: { value in
                                songTargetLetters[template.id] = value
                            }
                        )
                        let clefBinding = Binding<StaffClefMode>(
                            get: {
                                songClefModes[template.id] ?? defaultClefMode
                            },
                            set: { value in
                                songClefModes[template.id] = value
                            }
                        )
                        SongCardView(
                            template: template,
                            namingMode: namingMode,
                            isSelected: selectedSong?.id == template.id,
                            selectedLetters: binding,
                            selectedClef: clefBinding,
                            onSelect: { selectedSong = template },
                            onStart: {
                                selectedSong = template
                                onStart(template, binding.wrappedValue, clefBinding.wrappedValue)
                            }
                        )
                    }
                }
            }
        }
        .cardStyle()
        .onChange(of: activeLevel) { newValue in
            guard let newValue, let current = selectedSong, current.level != newValue else { return }
            selectedSong = nil
        }
        .onAppear {
            if activeLevel == nil {
                let grouped = Dictionary(grouping: SongTemplate.library, by: \.level)
                activeLevel = grouped.keys.sorted().first
            }
        }
    }
}

struct SongCardView: View {
    let template: SongTemplate
    let namingMode: NoteNamingMode
    let isSelected: Bool
    @Binding var selectedLetters: Set<NoteLetter>
    @Binding var selectedClef: StaffClefMode
    let onSelect: () -> Void
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(template.title)
                    .font(.custom("AvenirNext-DemiBold", size: CuteTheme.FontSize.body))
                    .foregroundColor(CuteTheme.textPrimary)

                let rhythmText: String = {
                    if template.isFixedMelody {
                        let rhythmLabel = template.melodyRhythmLabel ?? "Mixed"
                        let suffix = template.isMixedRhythm ? " / Mixed" : ""
                        return "Rhythm \(rhythmLabel)\(suffix)"
                    }
                    let intervalText: String = template.noteIntervalBeats == floor(template.noteIntervalBeats)
                        ? "\(Int(template.noteIntervalBeats))"
                        : String(format: "%.1f", template.noteIntervalBeats)
                    return "Every \(intervalText) beat"
                }()

                HStack(spacing: 8) {
                    ZenMetaTag(text: "BPM \(Int(template.bpm))")
                    ZenMetaTag(text: "Duration \(Int(template.duration))s")
                    ZenMetaTag(text: rhythmText)
                }
            }

            ZenDivider()

            HStack(alignment: .center, spacing: 12) {
                Text("Clef.Title")
                    .font(.custom("AvenirNext-Regular", size: CuteTheme.FontSize.caption))
                    .foregroundColor(CuteTheme.textSecondary)
                Spacer()
                ZenClefPicker(selection: $selectedClef)
            }

            ZenDivider()

            let letters = NoteLetter.allCases.filter { template.allowedLetters.contains($0) }
            Text("Training Notes")
                .font(.custom("AvenirNext-Regular", size: CuteTheme.FontSize.caption))
                .foregroundColor(CuteTheme.textSecondary)

            let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(letters, id: \.self) { letter in
                    Button(action: { toggle(letter) }) {
                        ZenLetterChip(
                            title: letter.displayName(for: namingMode),
                            isSelected: selectedLetters.contains(letter)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Button(action: onStart) {
                Text("Start")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ZenActionButtonStyle())
            .disabled(selectedLetters.isEmpty)
            .opacity(selectedLetters.isEmpty ? 0.5 : 1)
        }
        .cardStyle()
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isSelected ? CuteTheme.accent : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }

    private func toggle(_ letter: NoteLetter) {
        if selectedLetters.contains(letter) {
            selectedLetters.remove(letter)
        } else {
            selectedLetters.insert(letter)
        }
    }
}

struct NoteChipView: View {
    let title: String
    let isSelected: Bool
    let isDimmed: Bool

    var body: some View {
        Text(title)
            .font(.custom("AvenirNext-DemiBold", size: CuteTheme.FontSize.body))
            .foregroundColor(foregroundColor)
            .frame(maxWidth: .infinity, minHeight: 34)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 1)
            )
            .cornerRadius(12)
    }

    private var foregroundColor: Color {
        if isSelected {
            return CuteTheme.textPrimary
        }
        if isDimmed {
            return CuteTheme.textSecondary
        }
        return CuteTheme.textPrimary
    }

    private var backgroundColor: Color {
        if isSelected {
            return CuteTheme.chipSelectedFill
        }
        if isDimmed {
            return CuteTheme.controlFill
        }
        return CuteTheme.chipFill
    }

    private var borderColor: Color {
        if isSelected {
            return CuteTheme.accent
        }
        if isDimmed {
            return CuteTheme.cardBorder
        }
        return CuteTheme.chipBorder
    }
}

private extension View {
    func cardStyle() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .cuteCard()
    }
}
