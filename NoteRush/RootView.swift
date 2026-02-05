import SwiftUI

struct RootView: View {
    private enum Step {
        case entry
        case selection
        case play
    }

    @AppStorage(AppSettingsKeys.appLanguage) private var appLanguageRaw: String = AppLanguage.system.rawValue
    @AppStorage(AppSettingsKeys.appTheme) private var appThemeRaw: String = AppTheme.zen.rawValue
    @AppStorage(AppSettingsKeys.staffClefMode) private var staffClefModeRaw: String = StaffClefMode.treble.rawValue
    @AppStorage(AppSettingsKeys.freePracticeClefMode) private var freePracticeClefModeRaw: String = StaffClefMode.treble.rawValue
    @State private var step: Step = .entry
    @State private var bpm: Double = 80
    @State private var namingMode: NoteNamingMode = .letters
    @State private var rhythm: NoteRhythm = PracticeLevel.library.first?.rhythm ?? .quarter
    @State private var selectedLetters: Set<NoteLetter> = PracticeLevel.library.first?.letters ?? []
    @State private var selectedLevel: PracticeLevel? = PracticeLevel.library.first
    @State private var selectedSong: SongTemplate?
    @State private var songClefModes: [UUID: StaffClefMode] = [:]
    @State private var selectionTab: SelectionTab = .practiceNotes
    @State private var activeSong: Song?
    @State private var activeClefMode: StaffClefMode?
    @State private var activeSongTemplate: SongTemplate?
    @State private var activeSongTargetLetters: Set<NoteLetter> = []
    @State private var isFreePractice: Bool = false

    var body: some View {
        content
            .environment(\.locale, appLanguage.locale)
            .onAppear {
                // Jason request: default everything to treble clef.
                staffClefModeRaw = StaffClefMode.treble.rawValue
                freePracticeClefModeRaw = StaffClefMode.treble.rawValue
            }
    }

    private var appLanguage: AppLanguage {
        return AppLanguage(rawValue: appLanguageRaw) ?? .system
    }

    private var staffClefMode: StaffClefMode {
        return StaffClefMode(rawValue: staffClefModeRaw) ?? .treble
    }

    private func buildSong(
        from template: SongTemplate,
        bpm: Double,
        clefMode: StaffClefMode,
        targetLetters: Set<NoteLetter>
    ) -> Song {
        if let melody = template.melody {
            return Song.generateFixed(
                title: template.title,
                bpm: bpm,
                timeSignature: .common,
                melody: melody,
                targetLetters: targetLetters,
                clefMode: clefMode
            )
        }

        return Song.generate(
            title: template.title,
            bpm: bpm,
            duration: template.duration,
            timeSignature: .common,
            rhythm: template.rhythm,
            spawnLetters: template.allowedLetters,
            targetLetters: targetLetters,
            clefMode: clefMode
        )
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .entry:
            EntryView {
                step = .selection
            }
        case .selection:
            SelectionView(
                bpm: $bpm,
                namingMode: $namingMode,
                rhythm: $rhythm,
                selectedLetters: $selectedLetters,
                selectedLevel: $selectedLevel,
                selectedSong: $selectedSong,
                songClefModes: $songClefModes,
                activeTab: $selectionTab,
                onStartPractice: {
                    let level = selectedLevel
                    let levelClefMode: StaffClefMode
                    if let level {
                        levelClefMode = level.clefMode
                    } else {
                        levelClefMode = StaffClefMode(rawValue: freePracticeClefModeRaw)
                            ?? staffClefMode
                    }
                    let allowedNotes: [StaffNote]?
                    if let level {
                        switch levelClefMode {
                        case .treble:
                            let range = level.trebleRange ?? level.indexRange
                            allowedNotes = StaffNote.all(for: StaffClef.treble).filter { range.contains($0.index) }
                        case .bass:
                            let range = level.bassRange ?? level.indexRange
                            allowedNotes = StaffNote.all(for: StaffClef.bass).filter { range.contains($0.index) }
                        case .grand:
                            allowedNotes = StaffNote.all(for: .grand)
                        }
                    } else {
                        allowedNotes = nil
                    }

                    // Endless practice: keep generating random notes forever.
                    // For practice, we spawn only the selected letters so every note is a target.
                    activeSong = Song.generateEndless(
                        title: "Practice \(Int(bpm)) BPM",
                        bpm: bpm,
                        timeSignature: .common,
                        rhythm: rhythm,
                        spawnLetters: selectedLetters,
                        targetLetters: selectedLetters,
                        allowedIndices: nil,
                        clefMode: levelClefMode,
                        allowedNotes: allowedNotes
                    )
                    activeClefMode = levelClefMode
                    activeSongTemplate = nil
                    activeSongTargetLetters = selectedLetters
                    isFreePractice = selectedLevel == nil
                    selectionTab = isFreePractice ? .practiceNotes : .levels
                    step = .play
                },
                onStartSong: { song, targetLetters, clefMode in
                    let songClefMode: StaffClefMode = clefMode
                    activeSong = buildSong(
                        from: song,
                        bpm: bpm,
                        clefMode: songClefMode,
                        targetLetters: targetLetters
                    )
                    activeClefMode = songClefMode
                    activeSongTemplate = song
                    activeSongTargetLetters = targetLetters
                    songClefModes[song.id] = songClefMode
                    isFreePractice = false
                    selectionTab = .songs
                    step = .play
                }
            )
        case .play:
            if let song = activeSong {
                let onChangeClef: ((StaffClefMode, Double) -> Void)? = {
                    if isFreePractice {
                        return { newMode, currentBpm in
                            freePracticeClefModeRaw = newMode.rawValue
                            activeSong = Song.generateEndless(
                                title: "Practice \(Int(currentBpm)) BPM",
                                bpm: currentBpm,
                                timeSignature: .common,
                                rhythm: rhythm,
                                spawnLetters: selectedLetters,
                                targetLetters: selectedLetters,
                                allowedIndices: nil,
                                clefMode: newMode,
                                allowedNotes: nil
                            )
                            activeClefMode = newMode
                        }
                    }
                    if let template = activeSongTemplate {
                        return { newMode, currentBpm in
                            activeSong = buildSong(
                                from: template,
                                bpm: currentBpm,
                                clefMode: newMode,
                                targetLetters: activeSongTargetLetters
                            )
                            activeClefMode = newMode
                            songClefModes[template.id] = newMode
                        }
                    }
                    return nil
                }()

                SongModeView(
                    song: song,
                    namingMode: $namingMode,
                    clefMode: activeClefMode,
                    onChangeClef: onChangeClef,
                    onExit: {
                        // Return to the page that started this session.
                        selectionTab = isFreePractice ? (selectedLevel == nil ? .practiceNotes : .levels) : .songs
                        step = .selection
                    }
                )
                    .id(song.id)
            } else {
                EntryView {
                    step = .selection
                }
            }
        }
    }
}

struct EntryView: View {
    let onStart: () -> Void
    @AppStorage(AppSettingsKeys.staffClefMode) private var staffClefModeRaw: String = StaffClefMode.treble.rawValue
    @AppStorage(AppSettingsKeys.useColoredNotes) private var useColoredNotes: Bool = false
    @AppStorage(AppSettingsKeys.noteDisplayRhythmMode) private var noteDisplayRhythmModeRaw: String = NoteDisplayRhythmMode.quarter.rawValue

    private var previewNote: StaffNote {
        let mode = StaffClefMode(rawValue: staffClefModeRaw) ?? .treble
        let notes = StaffNote.all(for: mode)
        return notes.first(where: { $0.index == 6 }) ?? notes[6]
    }

    private var previewColor: Color {
        guard useColoredNotes else { return .black }
        return CuteTheme.noteColor(for: previewNote.letter)
    }

    private var previewRhythm: NoteRhythm {
        let mode = NoteDisplayRhythmMode(rawValue: noteDisplayRhythmModeRaw) ?? .quarter
        return mode.resolvedRhythm(seed: previewNote.id)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [CuteTheme.backgroundTop, CuteTheme.backgroundBottom]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Welcome to SightNote")
                        .font(.system(size: CuteTheme.FontSize.titleXL, weight: .bold, design: .rounded))
                        .foregroundColor(CuteTheme.textPrimary)
                    Text("Read ahead and hit notes in time")
                        .font(.system(size: CuteTheme.FontSize.section, weight: .medium, design: .rounded))
                        .foregroundColor(CuteTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }

                StaffView(
                    note: previewNote,
                    flashCorrect: false,
                    shakeTrigger: 0,
                    rhythm: previewRhythm,
                    clefMode: StaffClefMode(rawValue: staffClefModeRaw) ?? .treble,
                    noteColor: previewColor
                )
                    .frame(height: 180)
                    .padding(.horizontal, 12)
                    .cuteCard()

                VStack(alignment: .leading, spacing: 10) {
                    EntryFeatureRow(title: "Scrolling staff", detail: "Notes move left to right")
                    EntryFeatureRow(title: "Hit feedback", detail: "Notes change color on hit/miss")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .cuteCard()

                Spacer(minLength: 0)

                Button(action: onStart) {
                    Text("Start Practice")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
    }
}

struct EntryFeatureRow: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(CuteTheme.accent)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.system(size: CuteTheme.FontSize.section, weight: .semibold, design: .rounded))
                .foregroundColor(CuteTheme.textPrimary)
            Spacer()
            Text(detail)
                .font(.system(size: CuteTheme.FontSize.body, weight: .regular, design: .rounded))
                .foregroundColor(CuteTheme.textSecondary)
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: CuteTheme.FontSize.button, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(configuration.isPressed ? CuteTheme.accentPressed : CuteTheme.accent)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(CuteTheme.accent.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.12), radius: configuration.isPressed ? 2 : 6, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: CuteTheme.FontSize.button, weight: .bold, design: .rounded))
            .foregroundColor(CuteTheme.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(configuration.isPressed ? CuteTheme.controlFillPressed : CuteTheme.controlFill)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(CuteTheme.controlBorder, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}
