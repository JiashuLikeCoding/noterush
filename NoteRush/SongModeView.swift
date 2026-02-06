import SwiftUI

struct SongModeView: View {
    @StateObject private var viewModel: SongViewModel
    @StateObject private var micDetector = MicrophonePitchDetector()
    @StateObject private var midiDetector = MidiNoteDetector()
    @Binding var namingMode: NoteNamingMode
    let onChangeClef: ((StaffClefMode, Double) -> Void)?
    let onExit: () -> Void
    @State private var bpmDraft: Double
    @State private var showSettings: Bool = false
    @AppStorage(AppSettingsKeys.staffClefMode) private var staffClefModeRaw: String = StaffClefMode.treble.rawValue
    @AppStorage(AppSettingsKeys.showNoteName) private var showNoteName: Bool = false
    @AppStorage(AppSettingsKeys.showJudgementNoteName) private var showJudgementNoteName: Bool = false
    @AppStorage(AppSettingsKeys.useColoredKeys) private var useColoredKeys: Bool = true
    @AppStorage(AppSettingsKeys.useColoredNotes) private var useColoredNotes: Bool = false
    @AppStorage(AppSettingsKeys.noteDisplayRhythmMode) private var noteDisplayRhythmModeRaw: String = NoteDisplayRhythmMode.quarter.rawValue
    @AppStorage(AppSettingsKeys.inputMode) private var inputModeRaw: String = InputMode.buttons.rawValue

    private var inputMode: InputMode {
        return InputMode(rawValue: inputModeRaw) ?? .buttons
    }

    private var microphoneInputEnabled: Bool { inputMode == .microphone }
    private var midiInputEnabled: Bool { inputMode == .midi }
    private let clefModeOverride: StaffClefMode?

    private var staffClefMode: StaffClefMode {
        if let clefModeOverride {
            return clefModeOverride
        }
        return StaffClefMode(rawValue: staffClefModeRaw) ?? .treble
    }

    private var displayRhythmMode: NoteDisplayRhythmMode {
        return NoteDisplayRhythmMode(rawValue: noteDisplayRhythmModeRaw) ?? .quarter
    }

    init(
        song: Song,
        namingMode: Binding<NoteNamingMode>,
        clefMode: StaffClefMode? = nil,
        onChangeClef: ((StaffClefMode, Double) -> Void)? = nil,
        onExit: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: SongViewModel(song: song))
        _namingMode = namingMode
        clefModeOverride = clefMode
        self.onChangeClef = onChangeClef
        self.onExit = onExit
        _bpmDraft = State(initialValue: song.bpm)
    }

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height
            let contentPadding: CGFloat = isLandscape ? 10 : 8
            let usesGrandStaff = staffClefMode == .grand
            let staffHeight = min(
                proxy.size.height * (usesGrandStaff ? (isLandscape ? 0.5 : 0.6) : (isLandscape ? 0.38 : 0.45)),
                usesGrandStaff ? (isLandscape ? 280 : 320) : (isLandscape ? 220 : 260)
            )
            let noteScale = CGFloat(viewModel.noteScale) * (isLandscape ? 0.95 : 0.85)

            ZStack {
                VStack(spacing: 10) {
                    SongNavigationBar(
                        isPaused: viewModel.isPaused,
                        onBack: onExit,
                        onTogglePause: {
                            viewModel.togglePause()
                        },
                        onOpenSettings: {
                            showSettings = true
                        }
                    )

                    if isLandscape {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                SongHeaderView(
                                    title: viewModel.song.title,
                                    bpm: viewModel.bpm,
                                    rhythmLabel: viewModel.song.rhythmLabel,
                                    progress: viewModel.progress
                                )

                                BpmControlView(bpm: $bpmDraft, onCommit: { value in
                                    viewModel.restart(withBpm: value)
                                })

                                ControlCard {
                                    NamingModePicker(namingMode: $namingMode)
                                }

                                if let onChangeClef {
                                    PracticeClefPicker(
                                        selectedMode: staffClefMode,
                                        onSelect: { mode in
                                            if mode != staffClefMode {
                                                onChangeClef(mode, viewModel.bpm)
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    } else {
                        SongHeaderView(
                            title: viewModel.song.title,
                            bpm: viewModel.bpm,
                            rhythmLabel: viewModel.song.rhythmLabel,
                            progress: viewModel.progress
                        )

                        BpmControlView(bpm: $bpmDraft, onCommit: { value in
                            viewModel.restart(withBpm: value)
                        })

                        ControlCard {
                            NamingModePicker(namingMode: $namingMode)
                        }

                        if let onChangeClef {
                            PracticeClefPicker(
                                selectedMode: staffClefMode,
                                onSelect: { mode in
                                    if mode != staffClefMode {
                                        onChangeClef(mode, viewModel.bpm)
                                    }
                                }
                            )
                        }
                    }

                    ScrollingStaffView(
                        events: viewModel.events,
                        currentTime: viewModel.currentTime,
                        scrollConfig: viewModel.scrollConfig,
                        noteScale: noteScale,
                        scrollSpeedMultiplier: viewModel.scrollSpeedMultiplier,
                        lastJudgement: viewModel.lastJudgement,
                        lastJudgementTime: viewModel.lastJudgementTime,
                        lastJudgementLetter: viewModel.lastJudgementLetter,
                        clefMode: staffClefMode,
                        showNoteName: showNoteName,
                        showJudgementNoteName: showJudgementNoteName,
                        useColoredNotes: useColoredNotes,
                        displayRhythmMode: displayRhythmMode,
                        namingMode: namingMode
                    )
                    .frame(maxWidth: .infinity, minHeight: staffHeight, maxHeight: staffHeight)
                    .layoutPriority(1)
                    .padding(.horizontal, 6)
                    .cuteCard()

                    AnswerGridView(mode: namingMode, useColoredKeys: useColoredKeys) { letter in
                        guard !microphoneInputEnabled else { return }
                        InputFeedbackManager.noteButtonTapped(letter: letter, referenceNote: viewModel.currentTargetNote)
                        viewModel.select(letter: letter)
                    }
                    .disabled(viewModel.isFinished || viewModel.isPaused || microphoneInputEnabled)
                    .opacity(microphoneInputEnabled ? 0.5 : 1)

                    GeometryReader { proxy in
                        let diameter = max(0, proxy.size.height + 12)
                        JudgementPulseView(
                            judgement: viewModel.lastJudgement,
                            currentTime: viewModel.currentTime,
                            lastJudgementTime: viewModel.lastJudgementTime,
                            showNoteName: showJudgementNoteName,
                            noteName: viewModel.lastJudgementLetter?.displayName(for: namingMode),
                            diameter: diameter
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .padding(contentPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .onAppear {
                    viewModel.start()
                    bpmDraft = viewModel.bpm
                    if microphoneInputEnabled {
                        micDetector.start()
                    }
                    if midiInputEnabled {
                        midiDetector.start()
                    }
                }
                .onDisappear {
                    viewModel.stop()
                    micDetector.stop()
                    midiDetector.stop()
                }
                .onChange(of: viewModel.bpm) { newValue in
                    bpmDraft = newValue
                }
                .onChange(of: microphoneInputEnabled) { isEnabled in
                    if isEnabled {
                        micDetector.start()
                    } else {
                        micDetector.stop()
                    }
                }
                .onChange(of: midiInputEnabled) { isEnabled in
                    if isEnabled {
                        midiDetector.start()
                    } else {
                        midiDetector.stop()
                    }
                }
                .onChange(of: viewModel.isPaused) { isPaused in
                    if isPaused {
                        micDetector.stop()
                    } else if microphoneInputEnabled {
                        micDetector.start()
                    }
                }
                .onChange(of: viewModel.isFinished) { isFinished in
                    if isFinished {
                        micDetector.stop()
                    }
                }
                .onReceive(micDetector.$lastDetectedLetter) { letter in
                    guard microphoneInputEnabled, !viewModel.isPaused, !viewModel.isFinished else { return }
                    guard let letter else { return }
                    viewModel.select(letter: letter)
                }
                .onReceive(midiDetector.$lastDetectedLetter) { letter in
                    guard midiInputEnabled, !viewModel.isPaused, !viewModel.isFinished else { return }
                    guard let letter else { return }
                    viewModel.select(letter: letter)
                }
                .blur(radius: (viewModel.isPaused || viewModel.isFinished) ? 4 : 0)

                if viewModel.isPaused && !viewModel.isFinished {
                    PauseOverlayView(
                        onResume: {
                            viewModel.resume()
                        },
                        onEnd: {
                            viewModel.endSession()
                        }
                    )
                }

                if viewModel.isFinished {
                    ResultOverlayView(
                        accuracy: viewModel.accuracy,
                        onRestart: {
                            viewModel.restart()
                            if microphoneInputEnabled {
                                micDetector.start()
                            }
                            if midiInputEnabled {
                                midiDetector.start()
                            }
                        },
                        onDone: onExit
                    )
                }
            }
            .zenBackground()
            .sheet(isPresented: $showSettings) {
                AppSettingsSheetView()
            }
        }
    }
}

struct ControlCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(10)
            .background(CuteTheme.cardBackground)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(CuteTheme.cardBorder, lineWidth: 1)
            )
    }
}

struct SongNavigationBar: View {
    let isPaused: Bool
    let onBack: () -> Void
    let onTogglePause: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(CuteTheme.controlFill)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(CuteTheme.cardBorder, lineWidth: 1)
                    )
            }
            .foregroundColor(CuteTheme.textPrimary)

            Spacer()

            let statusKey: LocalizedStringKey = isPaused ? "Paused" : "Now Playing"
            Text(statusKey)
                .font(.system(size: CuteTheme.FontSize.nav, weight: .semibold, design: .rounded))
                .foregroundColor(CuteTheme.textSecondary)

            Spacer()

            HStack(spacing: 8) {
                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(CuteTheme.controlFill)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(CuteTheme.cardBorder, lineWidth: 1)
                        )
                }
                .foregroundColor(CuteTheme.textPrimary)

                Button(action: onTogglePause) {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(CuteTheme.controlFill)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(CuteTheme.cardBorder, lineWidth: 1)
                        )
                }
                .foregroundColor(CuteTheme.textPrimary)
            }
        }
    }
}

struct SongHeaderView: View {
    let title: String
    let bpm: Double
    let rhythmLabel: String
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: CuteTheme.FontSize.title, weight: .bold, design: .rounded))
                    .foregroundColor(CuteTheme.textPrimary)
                Spacer()
            }

            ProgressView(value: progress)
                .tint(CuteTheme.accent)

            HStack(spacing: 8) {
                ZenMetaTag {
                    Text("Tag.BPM \(Int(bpm))")
                }
                ZenMetaTag {
                    Text("Tag.Rhythm") + Text(" ") + Text(verbatim: rhythmLabel)
                }
            }
        }
        .padding(14)
        .background(CuteTheme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(CuteTheme.cardBorder, lineWidth: 1)
        )
    }
}

struct BpmControlView: View {
    @Binding var bpm: Double
    let onCommit: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("BPM")
                    .font(.system(size: CuteTheme.FontSize.caption, weight: .semibold, design: .rounded))
                    .foregroundColor(CuteTheme.textPrimary)
                Spacer()
                Text("\(Int(bpm))")
                    .font(.system(size: CuteTheme.FontSize.caption, weight: .semibold, design: .rounded))
                    .foregroundColor(CuteTheme.textPrimary)
            }

            Slider(
                value: $bpm,
                in: 30...200,
                step: 2,
                onEditingChanged: { editing in
                    if !editing {
                        onCommit(bpm)
                    }
                }
            )
            .tint(CuteTheme.accent)

            let presets = [30, 60, 80, 100, 120]
            HStack(spacing: 8) {
                ForEach(presets, id: \.self) { value in
                    Button(action: {
                        bpm = Double(value)
                        onCommit(bpm)
                    }) {
                        Text("\(value)")
                            .font(.system(size: CuteTheme.FontSize.caption, weight: .semibold, design: .rounded))
                            .foregroundColor(Int(bpm) == value ? .white : CuteTheme.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: 30)
                            .background(Int(bpm) == value ? CuteTheme.accent : CuteTheme.controlFill)
                            .cornerRadius(9)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
        .background(CuteTheme.cardBackground)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(CuteTheme.cardBorder, lineWidth: 1)
        )
    }
}


struct NamingModePicker: View {
    @Binding var namingMode: NoteNamingMode

    var body: some View {
        HStack(spacing: 12) {
            ForEach(NoteNamingMode.allCases) { mode in
                Button(action: { namingMode = mode }) {
                    VStack(spacing: 6) {
                        Text(mode.segmentTitle)
                            .font(.custom("AvenirNext-DemiBold", size: CuteTheme.FontSize.body))
                            .foregroundColor(namingMode == mode ? CuteTheme.textPrimary : CuteTheme.textSecondary)
                        Rectangle()
                            .fill(namingMode == mode ? CuteTheme.accent : Color.clear)
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

struct PracticeClefPicker: View {
    let selectedMode: StaffClefMode
    let onSelect: (StaffClefMode) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("Clef.Title")
                .font(.custom("AvenirNext-Regular", size: CuteTheme.FontSize.caption))
                .foregroundColor(CuteTheme.textSecondary)
            Spacer()
            let binding = Binding<StaffClefMode>(
                get: { selectedMode },
                set: { onSelect($0) }
            )
            ZenClefPicker(selection: binding)
        }
    }
}

struct PauseOverlayView: View {
    let onResume: () -> Void
    let onEnd: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Paused")
                .font(.custom("AvenirNext-DemiBold", size: CuteTheme.FontSize.title))
                .foregroundColor(CuteTheme.textPrimary)
            Text("Tap resume to continue the song.")
                .font(.custom("AvenirNext-Regular", size: CuteTheme.FontSize.body))
                .foregroundColor(CuteTheme.textSecondary)

            Button(action: onResume) {
                Text("Resume")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())

            Button(action: onEnd) {
                Text("End")
                    .font(.system(size: CuteTheme.FontSize.button, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(CuteTheme.accent)
                    .cornerRadius(14)
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(maxWidth: 320)
        .background(CuteTheme.cardBackground)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(CuteTheme.cardBorder, lineWidth: 1)
        )
    }
}

struct ResultOverlayView: View {
    let accuracy: Double
    let onRestart: () -> Void
    let onDone: () -> Void

    var body: some View {
        let percentage = max(0, min(Int((accuracy * 100).rounded()), 100))

        VStack(spacing: 16) {
            Text("Accuracy")
                .font(.custom("AvenirNext-DemiBold", size: CuteTheme.FontSize.title))
                .foregroundColor(CuteTheme.textPrimary)

            Text("\(percentage)%")
                .font(.custom("AvenirNext-Bold", size: 36))
                .foregroundColor(CuteTheme.textPrimary)

            Button(action: onRestart) {
                Text("Restart")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())

            Button(action: onDone) {
                Text("Done")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(24)
        .frame(maxWidth: 320)
        .background(CuteTheme.cardBackground)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(CuteTheme.cardBorder, lineWidth: 1)
        )
    }
}

struct JudgementPulseView: View {
    let judgement: Judgement?
    let currentTime: TimeInterval
    let lastJudgementTime: TimeInterval
    let showNoteName: Bool
    let noteName: String?
    let diameter: CGFloat

    var body: some View {
        let duration = 0.45
        let age = currentTime - lastJudgementTime
        let shouldShow = age >= 0 && age <= duration
        let progress = min(max(age / duration, 0), 1)
        let scale = 0.9 + progress * 0.3
        let opacity = 1 - progress
        let textScale = 0.95 + progress * 0.15
        let baseTextSize = max(18, min(diameter * 0.22, 36))

        return Group {
            if judgement != nil, shouldShow {
                let color = color(for: judgement)
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                    Circle()
                        .stroke(color.opacity(0.85), lineWidth: 2)
                    Circle()
                        .stroke(color.opacity(0.25), lineWidth: 8)
                        .blur(radius: 6)
                    if showNoteName, let noteName = noteName {
                        Text(noteName)
                            .font(.system(size: baseTextSize, weight: .bold, design: .rounded))
                            .foregroundColor(color)
                            .scaleEffect(textScale)
                            .opacity(opacity)
                    }
                }
                .frame(width: diameter, height: diameter)
                .scaleEffect(scale)
                .opacity(opacity)
            } else {
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func color(for judgement: Judgement?) -> Color {
        switch judgement {
        case .perfect:
            return CuteTheme.feedbackSuccess
        case .miss:
            return CuteTheme.feedbackMiss
        case .none:
            return .clear
        }
    }
}
