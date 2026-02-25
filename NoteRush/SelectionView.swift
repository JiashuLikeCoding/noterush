import SwiftUI

enum SelectionTab: String, CaseIterable, Identifiable {
    case practiceNotes
    case songs
    case levels
    case earTraining
    case records

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .practiceNotes:
            return "Tab.PracticeNotes"
        case .songs:
            return "Tab.Songs"
        case .levels:
            return "Tab.Levels"
        case .earTraining:
            return "Tab.EarTraining"
        case .records:
            return "Tab.Records"
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
    @Binding var activeTab: SelectionTab
    let onStartPractice: () -> Void
    let onStartSong: (SongTemplate, Set<NoteLetter>, StaffClefMode) -> Void

    // New kid-friendly lobby flow (screen-by-screen migration).
    @State private var showingSettings: Bool = false
    @State private var showLobby: Bool = true

    @StateObject private var midiMonitor = MidiDeviceMonitor()
    @State private var showMidiDetectedAlert: Bool = false
    @State private var lastHadMidiSources: Bool = false

    // QuickPickSheet removed (HOME no longer has the big "开始练习" button).

    @AppStorage(AppSettingsKeys.soundEffectsEnabled) private var soundEnabled: Bool = true
    @AppStorage(AppSettingsKeys.appLanguage) private var appLanguageRaw: String = AppLanguage.system.rawValue
    @AppStorage(AppSettingsKeys.appTheme) private var appThemeRaw: String = AppTheme.zen.rawValue
    @AppStorage(AppSettingsKeys.staffClefMode) private var staffClefModeRaw: String = StaffClefMode.treble.rawValue
    @AppStorage(AppSettingsKeys.showNoteName) private var showNoteName: Bool = false
    // Feedback note-name display removed per product direction.
    private let showJudgementNoteName: Bool = false
    @AppStorage(AppSettingsKeys.freePracticeClefMode) private var freePracticeClefModeRaw: String = StaffClefMode.treble.rawValue
    @AppStorage(AppSettingsKeys.useColoredKeys) private var useColoredKeys: Bool = true
    @AppStorage(AppSettingsKeys.useColoredNotes) private var useColoredNotes: Bool = false
    @AppStorage(AppSettingsKeys.noteDisplayRhythmMode) private var noteDisplayRhythmModeRaw: String = NoteDisplayRhythmMode.quarter.rawValue
    @AppStorage(AppSettingsKeys.microphoneInputEnabled) private var microphoneInputEnabled: Bool = false
    @AppStorage(AppSettingsKeys.midiInputEnabled) private var midiInputEnabled: Bool = false
    @AppStorage(AppSettingsKeys.inputMode) private var inputModeRaw: String = InputMode.buttons.rawValue

    @State private var songTargetLetters: [UUID: Set<NoteLetter>] = [:]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 14) {
                if showingSettings {
                    JellyTopBar(
                        titleEN: "SETTINGS",
                        titleZH: "设置",
                        onBack: { showingSettings = false },
                        onSettings: nil
                    )
                    .zIndex(10)
                } else if !showLobby {
                    JellyTopBar(
                        titleEN: titleEN(for: activeTab),
                        titleZH: titleZH(for: activeTab),
                        onBack: { withAnimation(.easeOut(duration: 0.18)) { showLobby = true } },
                        onSettings: { showingSettings.toggle() }
                    )
                    .zIndex(10)
                }

                if showingSettings {
                    ScrollView {
                        AppSettingsCard(
                            soundEnabled: $soundEnabled,
                            appLanguageRaw: $appLanguageRaw,
                            showNoteName: $showNoteName,
                            // showJudgementNoteName removed
                            useColoredKeys: $useColoredKeys,
                            useColoredNotes: $useColoredNotes,
                            noteDisplayRhythmModeRaw: $noteDisplayRhythmModeRaw
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                } else if showLobby {
                SelectionLobby(
                    namingMode: $namingMode,
                    onPickPractice: {
                        activeTab = .practiceNotes
                        withAnimation(.easeOut(duration: 0.18)) { showLobby = false }
                    },
                    onPickLevel: {
                        activeTab = .levels
                        withAnimation(.easeOut(duration: 0.18)) { showLobby = false }
                    },
                    onPickListen: {
                        activeTab = .earTraining
                        withAnimation(.easeOut(duration: 0.18)) { showLobby = false }
                    },
                    onPickSong: {
                        activeTab = .songs
                        withAnimation(.easeOut(duration: 0.18)) { showLobby = false }
                    },
                    onPickRecords: {
                        activeTab = .records
                        withAnimation(.easeOut(duration: 0.18)) { showLobby = false }
                    }
                )
                .padding(.horizontal, 16)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
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
                        case .earTraining:
                            EarTrainingSelectionCard(namingMode: $namingMode)
                        case .records:
                            RecordsView()
                        }
                    }
                    .padding(.horizontal, 16)
                    // Extra bottom breathing room so the glass card shows rounded corners
                    // above the home indicator and doesn't look "cut off".
                    .padding(.bottom, 90)
                }
                // Prevent ScrollView from clipping rounded corners/shadows during scroll.
                .scrollClipDisabled()
                // Add a little extra inset so the last card can always show its rounded corners.
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 24)
                }
            }

            Spacer(minLength: 0)
        }

        // HOME: keep ONLY the settings icon at top-right.
        if showLobby && !showingSettings {
            Button(action: { showingSettings = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(KidTheme.textOnBackgroundPrimary)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.16))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .padding(.trailing, 16)
            .padding(.top, 12)
        }
    }
    .kidBackground()
    .onAppear {
        midiMonitor.start()
        lastHadMidiSources = midiMonitor.hasSources
    }
    .onChange(of: showingSettings) { isShowing in
        // When opening settings, stay on current screen; when closing settings, return to lobby.
        if !isShowing {
            // Keep last selected tab but return to lobby so the app feels like a game hub.
            showLobby = true
        }
    }
    .onChange(of: midiMonitor.hasSources) { hasSources in
        // Only alert on transition: no -> yes
        if !lastHadMidiSources && hasSources {
            showMidiDetectedAlert = true
        }
        lastHadMidiSources = hasSources
    }
    .alert("MIDI.DeviceDetected.Title", isPresented: $showMidiDetectedAlert) {
        Button("OK") {}
    } message: {
        Text("MIDI.DeviceDetected.Message")
    }
    // QuickPickSheet removed.

}
}

// MARK: - Kid Lobby

private struct SelectionLobby: View {
    @Binding var namingMode: NoteNamingMode
    let onPickPractice: () -> Void
    let onPickLevel: () -> Void
    let onPickListen: () -> Void
    let onPickSong: () -> Void
    let onPickRecords: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Text("♪")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(Color.white.opacity(0.9))
                    Text("音乐小天才")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundColor(Color.white)
                    Text("♪")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(Color.white.opacity(0.9))
                }

                Text("让我们一起学习五线谱和音符吧！")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))
            }
            .padding(.top, 18)

            // Big glass card
            ZStack {
                RoundedRectangle(cornerRadius: 34)
                    .fill(Color.white.opacity(0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 34)
                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.14), radius: 24, x: 0, y: 16)

                VStack(spacing: 16) {
                    Image(systemName: "music.note")
                        .font(.system(size: 34, weight: .black))
                        .foregroundColor(Color.white.opacity(0.95))
                        .padding(.top, 6)

                    // Global naming mode (CDE vs Do Re Mi). Applies to all 4 modes before starting.
                    NamingModeQuickToggle(namingMode: $namingMode)

                    // Mode pills should evenly split the remaining space.
                    GeometryReader { geo in
                        let count: CGFloat = 5
                        let spacing: CGFloat = 10
                        let available = max(0, geo.size.height)
                        let buttonHeight = max(52, (available - spacing * (count - 1)) / count)

                        VStack(spacing: spacing) {
                            HomePillButton(title: "闯关", subtitle: "挑战关卡，拿星星", colors: [KidTheme.success, KidTheme.success.opacity(0.7)], systemImage: "flag.checkered", action: onPickLevel)
                                .frame(height: buttonHeight)

                            HomePillButton(title: "听音训练", subtitle: "听声音猜音符", colors: [KidTheme.primary, KidTheme.primary.opacity(0.7)], systemImage: "ear", action: onPickListen)
                                .frame(height: buttonHeight)

                            HomePillButton(title: "歌曲", subtitle: "练熟悉的旋律", colors: [KidTheme.accent, KidTheme.accent.opacity(0.7)], systemImage: "music.note.list", action: onPickSong)
                                .frame(height: buttonHeight)

                            HomePillButton(title: "自由练习", subtitle: "认识五线谱上的音符", colors: [Color(red: 1.00, green: 0.62, blue: 0.80), Color(red: 0.55, green: 0.84, blue: 1.00)], systemImage: "eyes", action: onPickPractice)
                                .frame(height: buttonHeight)

                            HomePillButton(title: "记录", subtitle: "查看练习统计", colors: [Color(red: 0.55, green: 0.76, blue: 1.00), Color(red: 0.35, green: 0.60, blue: 1.00)], systemImage: "chart.bar.xaxis", action: onPickRecords)
                                .frame(height: buttonHeight)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }

                    Spacer(minLength: 4)
                }
                .padding(22)
            }
            .frame(maxWidth: .infinity)

            // Bottom "开始练习" button removed per product direction.

            Spacer(minLength: 6)
        }
        .padding(.top, 2)
    }
}


private struct ModeCard: View {
    let titleEN: String
    let titleZH: String
    let subtitle: String
    let tint: Color
    let symbol: String

    var body: some View {
        JellyCard(tint: tint) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(tint.opacity(0.14))
                        .frame(width: 56, height: 56)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(KidTheme.border, lineWidth: 1)
                        )

                    Image(systemName: symbol)
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(tint)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(titleEN)
                            .font(.system(size: KidTheme.FontSize.title, weight: .heavy, design: .rounded))
                            .foregroundColor(KidTheme.textPrimary)

                        JellyPill(text: titleZH, tint: tint)
                    }

                    Text(subtitle)
                        .font(.system(size: KidTheme.FontSize.caption, weight: .medium, design: .rounded))
                        .foregroundColor(KidTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(KidTheme.textSecondary)
            }
        }
    }
}

private struct NamingModeQuickToggle: View {
    @Binding var namingMode: NoteNamingMode

    var body: some View {
        HStack(spacing: 18) {
            ForEach(NoteNamingMode.allCases) { mode in
                Button(action: { namingMode = mode }) {
                    VStack(spacing: 8) {
                        Text(mode.segmentTitle)
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)

                        Rectangle()
                            .fill(namingMode == mode ? Color.white.opacity(0.95) : Color.white.opacity(0.0))
                            .frame(height: 3)
                            .cornerRadius(2)
                            .padding(.horizontal, 6)
                    }
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.12))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct HomePillButton: View {
    let title: String
    let subtitle: String
    let colors: [Color]
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(.white.opacity(0.95))
                    .frame(width: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.86))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.90))
            }
            .padding(.horizontal, 16)
            .frame(height: 72)
            .background(
                LinearGradient(
                    colors: colors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.18), radius: 14, x: 0, y: 10)
        }
        .buttonStyle(.plain)
    }
}

// (moved to shared JellyComponents.swift)

private struct QuickPickSheet: View {
    let onPickLevel: () -> Void
    let onPickListen: () -> Void
    let onPickSong: () -> Void
    let onPickPractice: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("选择练习方式")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundColor(KidTheme.textOnCardPrimary)
                .padding(.top, 10)

            HomePillButton(title: "闯关", subtitle: "挑战关卡，拿星星", colors: [KidTheme.success, KidTheme.success.opacity(0.75)], systemImage: "flag.checkered", action: onPickLevel)
            HomePillButton(title: "听音训练", subtitle: "听声音猜音符", colors: [KidTheme.primary, KidTheme.primary.opacity(0.75)], systemImage: "ear", action: onPickListen)
            HomePillButton(title: "歌曲", subtitle: "练熟悉的旋律", colors: [KidTheme.accent, KidTheme.accent.opacity(0.75)], systemImage: "music.note.list", action: onPickSong)
            HomePillButton(title: "自由练习", subtitle: "认识五线谱上的音符", colors: [Color(red: 1.00, green: 0.62, blue: 0.80), Color(red: 0.55, green: 0.84, blue: 1.00)], systemImage: "eyes", action: onPickPractice)

            Spacer(minLength: 4)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .background(Color.white.opacity(0.96))
    }
}

// MARK: - Tab title mapping

private extension SelectionView {
    func titleEN(for tab: SelectionTab) -> String {
        switch tab {
        case .practiceNotes: return "PRACTICE"
        case .songs: return "SONG"
        case .levels: return "LEVEL"
        case .earTraining: return "LISTEN"
        case .records: return "RECORDS"
        }
    }

    func titleZH(for tab: SelectionTab) -> String {
        switch tab {
        case .practiceNotes: return "练习"
        case .songs: return "歌曲"
        case .levels: return "闯关"
        case .earTraining: return "听音训练"
        case .records: return "记录"
        }
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

struct ZenMetaTag<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
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
                let isSelected = selection == mode
                Button(action: { selection = mode }) {
                    Text(mode.titleKey)
                        .font(.custom("AvenirNext-DemiBold", size: KidTheme.FontSize.body))
                        .foregroundColor(isSelected ? .white : KidTheme.textOnCardPrimary)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(isSelected ? KidTheme.primary : KidTheme.surface)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(KidTheme.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(KidTheme.surfaceStrong)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(KidTheme.border, lineWidth: 1)
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
        HStack(spacing: 10) {
            ForEach(AppTheme.allCases) { theme in
                Button(action: { selectedRaw = theme.rawValue }) {
                    ThemeSwatch(theme: theme, isSelected: selectedRaw == theme.rawValue)
                        .frame(maxWidth: .infinity)
                        .contentShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 0)
    }
}

struct ThemeSwatch: View {
    let theme: AppTheme
    let isSelected: Bool

    var body: some View {
        let palette = theme.palette

        VStack(spacing: 6) {
            Circle()
                .fill(palette.accent)
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(isSelected ? palette.accent : CuteTheme.controlBorder, lineWidth: isSelected ? 3 : 1)
                )

            Text(theme.displayName)
                .font(.custom("AvenirNext-DemiBold", size: 10))
                .foregroundColor(CuteTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? palette.accent.opacity(0.18) : CuteTheme.controlFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? palette.accent.opacity(0.45) : CuteTheme.controlBorder, lineWidth: 1)
        )
    }
}

struct AppSettingsCard: View {
    @Binding var soundEnabled: Bool
    @Binding var appLanguageRaw: String
    @Binding var showNoteName: Bool
    // showJudgementNoteName removed
    @Binding var useColoredKeys: Bool
    @Binding var useColoredNotes: Bool
    @Binding var noteDisplayRhythmModeRaw: String
    @State private var showingLanguagePicker: Bool = false

    var body: some View {
        // Settings UI is now fixed to the KidTheme look.
        let accent = KidTheme.primary

        VStack(alignment: .leading, spacing: 12) {
            Text("App Settings")
                .font(.system(size: CuteTheme.FontSize.section, weight: .bold, design: .rounded))
                .foregroundColor(KidTheme.textOnCardPrimary)

            Toggle("Sound Effects", isOn: $soundEnabled)
                .tint(accent)

            Toggle("Show Note Name", isOn: $showNoteName)
                .tint(accent)

            // "Show Feedback Note Name" removed

            Toggle("Color Answer Keys", isOn: $useColoredKeys)
                .tint(accent)

            Toggle("Color Notes", isOn: $useColoredNotes)
                .tint(accent)

            VStack(alignment: .leading, spacing: 8) {
                Text("Note Display")
                    .font(.custom("AvenirNext-Regular", size: CuteTheme.FontSize.body))
                    .foregroundColor(KidTheme.textOnCardSecondary)

                let modes = NoteDisplayRhythmMode.allCases
                HStack(spacing: 8) {
                    ForEach(modes) { mode in
                        Button(action: {
                            noteDisplayRhythmModeRaw = mode.rawValue
                        }) {
                            Text(mode.titleKey)
                                .font(.custom("AvenirNext-DemiBold", size: CuteTheme.FontSize.caption))
                                .foregroundColor(noteDisplayRhythmModeRaw == mode.rawValue ? .white : KidTheme.textOnCardPrimary)
                                .frame(maxWidth: .infinity, minHeight: 32)
                                .background(noteDisplayRhythmModeRaw == mode.rawValue ? accent : KidTheme.surface)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(KidTheme.border, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Language")
                    .font(.custom("AvenirNext-Regular", size: CuteTheme.FontSize.body))
                    .foregroundColor(KidTheme.textOnCardSecondary)

                let languages = AppLanguage.allCases
                let selectedLanguage = AppLanguage(rawValue: appLanguageRaw) ?? .system

                Button(action: { showingLanguagePicker = true }) {
                    HStack(spacing: 10) {
                        Text(selectedLanguage.flag)
                        Text(selectedLanguage.nativeName)
                            .font(.custom("AvenirNext-DemiBold", size: CuteTheme.FontSize.body))
                            .foregroundColor(KidTheme.textOnCardPrimary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(KidTheme.textOnCardSecondary)
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 40)
                    .background(KidTheme.surface)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(KidTheme.border, lineWidth: 1)
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
        JellyCard(tint: KidTheme.primary) {
            VStack(alignment: .leading, spacing: 14) {
                JellySectionHeader(
                    titleEN: "PRACTICE",
                    titleZH: "自由练习",
                    symbol: "music.quarternote.3",
                    tint: KidTheme.primary
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("谱号")
                        .font(.system(size: KidTheme.FontSize.caption, weight: .semibold, design: .rounded))
                        .foregroundColor(KidTheme.textSecondary)

                    let clefBinding = Binding<StaffClefMode>(
                        get: { StaffClefMode(rawValue: freePracticeClefModeRaw) ?? .treble },
                        set: { newMode in
                            freePracticeClefModeRaw = newMode.rawValue
                            selectedLevel = nil
                        }
                    )
                    ZenClefPicker(selection: clefBinding)
                        .frame(maxWidth: .infinity)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("训练音")
                        .font(.system(size: KidTheme.FontSize.caption, weight: .semibold, design: .rounded))
                        .foregroundColor(KidTheme.textSecondary)

                    let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(NoteLetter.allCases, id: \.self) { letter in
                            Button(action: { toggle(letter) }) {
                                JellyLetterChip(
                                    title: letter.displayName(for: namingMode),
                                    isSelected: selectedLetters.contains(letter)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if selectedLetters.isEmpty {
                    Text("请选择至少一个音")
                        .font(.system(size: KidTheme.FontSize.caption, weight: .semibold, design: .rounded))
                        .foregroundColor(KidTheme.danger)
                }

                Button(action: {
                    selectedLevel = nil
                    onStart()
                }) {
                    Text("开始练习")
                }
                .buttonStyle(JellyButtonStyle(kind: .primary))
                .disabled(selectedLetters.isEmpty)
                .opacity(selectedLetters.isEmpty ? 0.5 : 1)
            }
        }
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
        JellyCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("LEVEL")
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundColor(KidTheme.textOnCardPrimary)
                        Text("闯关")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(KidTheme.textOnCardSecondary)
                    }

                    Spacer()

                    Image(systemName: "flag.checkered")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundColor(KidTheme.success)
                        .padding(10)
                        .background(KidTheme.success.opacity(0.12))
                        .cornerRadius(14)
                }

                VStack(spacing: 12) {
                    ForEach(PracticeLevel.library) { level in
                        LevelCardView(
                            level: level,
                            isSelected: selectedLevel?.id == level.id,
                            onSelect: { apply(level) },
                            onStart: {
                                apply(level)
                                onStart(level)
                            }
                        )
                    }
                }
            }
        }
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
    let onSelect: () -> Void
    let onStart: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.04))
                            .frame(width: 44, height: 44)
                        Text("L\(level.id)")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundColor(KidTheme.textOnCardPrimary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(level.titleKey)
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundColor(KidTheme.textOnCardPrimary)
                        Text(level.subtitleKey)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(KidTheme.textOnCardSecondary)
                    }

                    Spacer()

                    JellyPill(text: level.rhythm.displayNameKey, tint: KidTheme.accent)
                }

                HStack(spacing: 8) {
                    ForEach(level.rangeTags.indices, id: \.self) { idx in
                        JellyPill(text: level.rangeTags[idx], tint: KidTheme.primary)
                    }
                }

                Button(action: onStart) {
                    Text("开始")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            LinearGradient(
                                colors: [KidTheme.primary, KidTheme.primaryPressed],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(22)
                        .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 8)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 26)
                    .fill(KidTheme.surfaceStrong)
                    .overlay(
                        RoundedRectangle(cornerRadius: 26)
                            .stroke(isSelected ? KidTheme.primary.opacity(0.65) : Color.black.opacity(0.06), lineWidth: isSelected ? 2 : 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.10), radius: 16, x: 0, y: 10)
        }
        .buttonStyle(.plain)
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
        JellyCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SONG")
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundColor(KidTheme.textOnCardPrimary)
                        Text("歌曲")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(KidTheme.textOnCardSecondary)
                    }

                    Spacer()

                    Image(systemName: "music.note.list")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundColor(KidTheme.primary)
                        .padding(10)
                        .background(KidTheme.primary.opacity(0.12))
                        .cornerRadius(14)
                }

                let grouped = Dictionary(grouping: SongTemplate.library, by: \.level)
                let levels = grouped.keys.sorted()
                let resolvedLevel = activeLevel ?? levels.first

                SongLevelTabBar(
                    levels: levels,
                    selectedLevel: resolvedLevel,
                    onSelect: { activeLevel = $0 }
                )

                if let level = resolvedLevel {
                    VStack(spacing: 12) {
                        ForEach(grouped[level] ?? []) { template in
                            SongCardView(
                                template: template,
                                isSelected: selectedSong?.id == template.id,
                                onSelect: { selectedSong = template },
                                onStart: {
                                    selectedSong = template
                                    onStart(template, template.allowedLetters, defaultClefMode)
                                }
                            )
                        }
                    }
                }
            }
        }
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
    let isSelected: Bool
    let onSelect: () -> Void
    let onStart: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                Text(template.title)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(KidTheme.textOnCardPrimary)

                // Per latest product direction: remove clef selection + training note selection.

                Button(action: onStart) {
                    Text("开始")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            LinearGradient(
                                colors: [KidTheme.primary, KidTheme.primaryPressed],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(22)
                        .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 8)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 26)
                    .fill(KidTheme.surfaceStrong)
                    .overlay(
                        RoundedRectangle(cornerRadius: 26)
                            .stroke(isSelected ? KidTheme.primary.opacity(0.65) : Color.black.opacity(0.06), lineWidth: isSelected ? 2 : 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.10), radius: 16, x: 0, y: 10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - SONG helpers (match LEVEL style)

private struct SongLevelTabBar: View {
    let levels: [Int]
    let selectedLevel: Int?
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 10) {
            ForEach(levels, id: \.self) { lvl in
                let isSelected = (lvl == selectedLevel)
                Button(action: { onSelect(lvl) }) {
                    Text("L\(lvl)")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(isSelected ? .white : KidTheme.textOnCardPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(isSelected ? KidTheme.primary : KidTheme.surface)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(KidTheme.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct SongClefPicker: View {
    @Binding var selection: StaffClefMode

    var body: some View {
        HStack(spacing: 8) {
            clefButton(title: "Treble", mode: .treble)
            clefButton(title: "Bass", mode: .bass)
            clefButton(title: "Grand", mode: .grand)
        }
        .padding(6)
        .background(KidTheme.surface)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(KidTheme.border, lineWidth: 1)
        )
    }

    private func clefButton(title: String, mode: StaffClefMode) -> some View {
        let isSelected = (selection == mode)
        return Button(action: { selection = mode }) {
            Text(title)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundColor(isSelected ? .white : KidTheme.textOnCardPrimary)
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(isSelected ? KidTheme.primary : Color.clear)
                .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }
}

private struct SongLetterChip: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .foregroundColor(isSelected ? .white : KidTheme.textOnCardPrimary)
            .frame(maxWidth: .infinity, minHeight: 34)
            .background(isSelected ? KidTheme.primary : KidTheme.surface)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(KidTheme.border, lineWidth: 1)
            )
    }
}

private struct RecordsCard: View {
    @AppStorage(AppSettingsKeys.recordsTotalAnswered) private var totalAnswered: Int = 0
    @AppStorage(AppSettingsKeys.recordsTotalCorrect) private var totalCorrect: Int = 0

    private var accuracyPercent: Int {
        guard totalAnswered > 0 else { return 0 }
        return max(0, min(100, Int((Double(totalCorrect) / Double(totalAnswered) * 100).rounded())))
    }

    var body: some View {
        JellyCard(tint: KidTheme.primary) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(KidTheme.primary.opacity(0.18))
                            .frame(width: 56, height: 56)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                            )

                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundColor(Color.white.opacity(0.95))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("RECORDS")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundColor(KidTheme.textOnCardSecondary)

                        Text("记录")
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .foregroundColor(KidTheme.textOnCardPrimary)
                    }

                    Spacer()

                    Text("\(accuracyPercent)%")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(KidTheme.textOnCardPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.14))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                }

                HStack(spacing: 12) {
                    StatChip(title: "已答题", value: "\(totalAnswered)")
                    StatChip(title: "答对", value: "\(totalCorrect)")
                    StatChip(title: "答错", value: "\(max(0, totalAnswered - totalCorrect))")
                }

                Text("提示：现在只统计按钮输入的判定次数（之后可以加按模式统计/连续天数）。")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(KidTheme.textOnCardSecondary)
            }
        }
    }
}

private struct StatChip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundColor(KidTheme.textOnCardSecondary)
            Text(value)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundColor(KidTheme.textOnCardPrimary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.10))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }
}

private extension View {
    /// Legacy wrapper used by older cards. Keep it for untouched screens.
    func cardStyle() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .cuteCard()
    }
}

