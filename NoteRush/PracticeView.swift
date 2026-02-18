import SwiftUI

struct PracticeView: View {
    @StateObject private var viewModel = PracticeViewModel()
    @StateObject private var micDetector = MicrophonePitchDetector()
    @StateObject private var midiDetector = MidiNoteDetector()

    private struct HeightKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }

    @State private var topContentHeight: CGFloat = 0
    @State private var stableKeyboardHeight: CGFloat = 260
    @AppStorage(AppSettingsKeys.staffClefMode) private var staffClefModeRaw: String = StaffClefMode.treble.rawValue
    @AppStorage(AppSettingsKeys.useColoredKeys) private var useColoredKeys: Bool = true
    @AppStorage(AppSettingsKeys.useColoredNotes) private var useColoredNotes: Bool = false
    @AppStorage(AppSettingsKeys.noteDisplayRhythmMode) private var noteDisplayRhythmModeRaw: String = NoteDisplayRhythmMode.quarter.rawValue
    @AppStorage(AppSettingsKeys.noteNamingMode) private var namingModeRaw: String = NoteNamingMode.letters.rawValue
    @AppStorage(AppSettingsKeys.inputMode) private var inputModeRaw: String = InputMode.buttons.rawValue

    private var inputMode: InputMode {
        return InputMode(rawValue: inputModeRaw) ?? .buttons
    }

    // Jason decision: keep app in button-only input mode.
    private var microphoneInputEnabled: Bool { false }
    private var midiInputEnabled: Bool { false }

    private var staffClefMode: StaffClefMode {
        return StaffClefMode(rawValue: staffClefModeRaw) ?? .treble
    }

    private var displayRhythm: NoteRhythm {
        let mode = NoteDisplayRhythmMode(rawValue: noteDisplayRhythmModeRaw) ?? .quarter
        return mode.resolvedRhythm(seed: viewModel.currentNote.id)
    }

    private var namingMode: NoteNamingMode {
        get { NoteNamingMode(rawValue: namingModeRaw) ?? .letters }
        nonmutating set { namingModeRaw = newValue.rawValue }
    }

    private var namingModeBinding: Binding<NoteNamingMode> {
        Binding(get: { self.namingMode }, set: { self.namingMode = $0 })
    }

    var body: some View {
        GeometryReader { geo in
            let horizontalPad: CGFloat = 16
            let verticalPad: CGFloat = 12
            let stackSpacing: CGFloat = 10
            let staffHeight: CGFloat = 240

            let bottomGap = geo.safeAreaInsets.bottom + 34

            // Remaining height after top content + staff + paddings/spacings + bottom gap.
            // We measure the top content (header + naming picker) so keyboard can fill the rest.
            let remaining = geo.size.height
                - verticalPad * 2
                - topContentHeight
                - stackSpacing
                - staffHeight
                - stackSpacing
                - bottomGap

            let proposedKeyboardHeight = min(260, max(220, remaining))

            VStack(spacing: stackSpacing) {
                // Merge top controls into ONE compact card (方案 A)
                ControlCard(padding: 8) {
                    VStack(spacing: 6) {
                        // ui rev marker removed

                        // Compact timer row (avoid nested card)
                        HStack {
                            Text("Time")
                                .font(.system(size: CuteTheme.FontSize.caption, weight: .semibold, design: .rounded))
                                .foregroundColor(CuteTheme.textPrimary)
                            Spacer()
                            Text(String(format: "%.1fs", max(0, viewModel.timeRemaining)))
                                .font(.system(size: CuteTheme.FontSize.caption, weight: .semibold, design: .rounded))
                                .foregroundColor(CuteTheme.textPrimary)
                        }

                        ProgressView(value: max(0, viewModel.timeRemaining), total: max(0.1, viewModel.timeLimit))
                            .tint(.black)

                        NamingModePicker(namingMode: namingModeBinding)

                        PracticeClefPicker(
                            selectedMode: staffClefMode,
                            onSelect: { mode in
                                if mode != staffClefMode {
                                    staffClefModeRaw = mode.rawValue
                                }
                            }
                        )
                    }
                }
                .background(
                    GeometryReader { p in
                        Color.clear
                            .preference(key: HeightKey.self, value: p.size.height)
                    }
                )

                StaffView(
                    note: viewModel.currentNote,
                    flashCorrect: viewModel.flashCorrect,
                    flashIncorrect: viewModel.flashIncorrect,
                    shakeTrigger: viewModel.shakeTrigger,
                    rhythm: displayRhythm,
                    clefMode: staffClefMode,
                    noteColor: noteColor(for: viewModel.currentNote)
                )
                .frame(height: staffHeight)
                .padding(.horizontal, 12)

                PianoKeyboardInputView(namingMode: namingMode, useColoredKeys: useColoredKeys) { letter in
                    guard !(microphoneInputEnabled || midiInputEnabled) else { return }
                    InputFeedbackManager.noteButtonTapped(letter: letter, referenceNote: viewModel.currentNote)
                    viewModel.select(letter: letter)
                }
                .frame(height: stableKeyboardHeight)
                .disabled(microphoneInputEnabled || midiInputEnabled)
                .opacity((microphoneInputEnabled || midiInputEnabled) ? 0.5 : 1)

                Spacer(minLength: bottomGap)
            }
            .padding(.horizontal, horizontalPad)
            .padding(.vertical, verticalPad)
            .cuteBackground()
            .onPreferenceChange(HeightKey.self) { newValue in
                // Avoid tiny measurement jitter from causing keyboard height changes.
                if abs(newValue - topContentHeight) > 1 {
                    topContentHeight = newValue
                }
            }
            .onAppear {
                stableKeyboardHeight = proposedKeyboardHeight
            }
            .onChange(of: geo.size) { _ in
                stableKeyboardHeight = proposedKeyboardHeight
            }
            .onChange(of: topContentHeight) { _ in
                stableKeyboardHeight = proposedKeyboardHeight
            }
        }
        .onAppear {
            viewModel.start()
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
        .onReceive(micDetector.$lastDetectedLetter) { letter in
            guard microphoneInputEnabled else { return }
            guard let letter else { return }
            viewModel.select(letter: letter)
        }
        .onReceive(midiDetector.$lastDetectedLetter) { letter in
            guard midiInputEnabled else { return }
            guard let letter else { return }
            viewModel.select(letter: letter)
        }
    }

    private func noteColor(for note: StaffNote) -> Color {
        guard useColoredNotes else { return .black }
        return CuteTheme.noteColor(for: note.letter)
    }
}

struct HeaderView: View {
    let timeRemaining: Double
    let timeLimit: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Time")
                    .font(.system(size: CuteTheme.FontSize.caption, weight: .semibold, design: .rounded))
                    .foregroundColor(CuteTheme.textPrimary)
                Spacer()
                Text(String(format: "%.1fs", max(0, timeRemaining)))
                    .font(.system(size: CuteTheme.FontSize.caption, weight: .semibold, design: .rounded))
                    .foregroundColor(CuteTheme.textPrimary)
            }

            ProgressView(value: max(0, timeRemaining), total: max(0.1, timeLimit))
                .tint(.black)
        }
        .padding(12)
        .background(CuteTheme.controlFill)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(CuteTheme.cardBorder, lineWidth: 1)
        )
    }
}

struct AnswerGridView: View {
    let mode: NoteNamingMode
    let enabledLetters: Set<NoteLetter>?
    let useColoredKeys: Bool
    let onSelect: (NoteLetter) -> Void

    init(
        mode: NoteNamingMode,
        enabledLetters: Set<NoteLetter>? = nil,
        useColoredKeys: Bool = true,
        onSelect: @escaping (NoteLetter) -> Void
    ) {
        self.mode = mode
        self.enabledLetters = enabledLetters
        self.useColoredKeys = useColoredKeys
        self.onSelect = onSelect
    }

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(NoteLetter.allCases, id: \.self) { letter in
                let isEnabled = enabledLetters?.contains(letter) ?? true
                let style = buttonStyle(for: letter, isEnabled: isEnabled, useColoredKeys: useColoredKeys)
                Button(action: { onSelect(letter) }) {
                    Text(letter.displayName(for: mode))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(style)
                .disabled(!isEnabled)
                .opacity(isEnabled ? 1 : 0.4)
            }
        }
    }

    private func buttonStyle(for letter: NoteLetter, isEnabled: Bool, useColoredKeys: Bool) -> NoteButtonStyle {
        let fill = useColoredKeys ? buttonColors(for: letter) : Color.black.opacity(0.45)
        return NoteButtonStyle(isEnabled: isEnabled, fillColor: fill)
    }

    private func buttonColors(for letter: NoteLetter) -> Color {
        return CuteTheme.noteColor(for: letter)
    }
}

struct NoteButtonStyle: ButtonStyle {
    let isEnabled: Bool
    let fillColor: Color

    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed && isEnabled
        let baseFill = isEnabled ? fillColor : CuteTheme.controlFill
        let pressedFill = isEnabled ? fillColor.opacity(0.75) : CuteTheme.controlFillPressed
        configuration.label
            .font(.system(size: CuteTheme.FontSize.button, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(isPressed ? pressedFill : baseFill)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(CuteTheme.controlBorder, lineWidth: 1)
            )
            .cornerRadius(14)
            .shadow(color: CuteTheme.cardShadow, radius: isPressed ? 0 : 6, x: 0, y: 4)
    }
}
