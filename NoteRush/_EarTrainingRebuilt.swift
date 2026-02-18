import SwiftUI
import AVFoundation
import Combine

// This file rebuilds the Ear Training (听音) flow that previously existed as untracked files.
// It is intentionally self-contained and minimal, and relies on shared domain types from PracticeViewModel.swift.

// MARK: - Levels

enum EarTrainingClefMode: String, CaseIterable, Identifiable {
    case treble
    case bass
    case grand

    var id: String { rawValue }

    var staffClefMode: StaffClefMode {
        switch self {
        case .treble: return .treble
        case .bass: return .bass
        case .grand: return .grand
        }
    }
}

struct EarTrainingLevel: Identifiable, Equatable {
    let id: Int
    let title: String
    let clefMode: StaffClefMode
    let midiRange: ClosedRange<Int>

    static let library: [EarTrainingLevel] = [
        EarTrainingLevel(id: 1, title: "关卡 1", clefMode: .treble, midiRange: 60...71), // C4..B4
        EarTrainingLevel(id: 2, title: "关卡 2", clefMode: .treble, midiRange: 57...84), // A3..C6
        EarTrainingLevel(id: 3, title: "关卡 3", clefMode: .bass, midiRange: 48...59),   // C3..B3
        EarTrainingLevel(id: 4, title: "关卡 4", clefMode: .bass, midiRange: 36...64),   // C2..E4
        EarTrainingLevel(id: 5, title: "关卡 5", clefMode: .grand, midiRange: 48...72),  // C3..C5 (narrower than before)
        EarTrainingLevel(id: 6, title: "关卡 6", clefMode: .grand, midiRange: 36...84)   // C2..C6
    ]
}

// MARK: - Audio (piano-ish)

final class PianoSoundEngine {
    static let shared = PianoSoundEngine()

    private let engine = AVAudioEngine()
    private let sampler = AVAudioUnitSampler()
    private var didStart = false

    private init() {
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)
    }

    func startIfNeeded() {
        guard !didStart else { return }

        // Load instrument FIRST (this is usually the source of the first-tap hitch).
        // Prefer bundled soundfont if present.
        if let sf2 = Bundle.main.url(forResource: "soundfont", withExtension: "sf2")
            ?? Bundle.main.url(forResource: "soundfont", withExtension: "sf2", subdirectory: "SoundFonts")
            ?? Bundle.main.url(forResource: "soundfont", withExtension: "sf2", subdirectory: "Resources/SoundFonts") {
            try? sampler.loadSoundBankInstrument(
                at: sf2,
                program: 0,
                bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                bankLSB: 0
            )
        } else {
            // Fallback: built-in GM soundbank.
            let url = URL(fileURLWithPath: "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls")
            if FileManager.default.fileExists(atPath: url.path) {
                try? sampler.loadSoundBankInstrument(
                    at: url,
                    program: 0,
                    bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                    bankLSB: 0
                )
            }
        }

        let session = AVAudioSession.sharedInstance()
        do {
            // We only need playback for keyboard sounds.
            try session.setCategory(.playback, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            // ignore
        }

        engine.prepare()
        do {
            try engine.start()
            didStart = true
        } catch {
            // ignore
        }
    }

    /// Call this early (e.g. on app launch) to avoid first-tap lag.
    func prewarm() {
        DispatchQueue.main.async {
            self.startIfNeeded()
        }
    }

    func play(midi: Int, duration: TimeInterval = 0.35, velocity: UInt8 = 96) {
        startIfNeeded()
        let note = UInt8(max(0, min(127, midi)))
        sampler.startNote(note, withVelocity: velocity, onChannel: 0)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.sampler.stopNote(note, onChannel: 0)
        }
    }
}

// MARK: - ViewModel

@MainActor
final class EarTrainingViewModel: ObservableObject {
    @Published private(set) var level: EarTrainingLevel
    @Published var notesPerQuestion: Int = 1

    @Published private(set) var targetMidi: [Int] = []
    @Published private(set) var inputMidi: [Int] = []

    @Published private(set) var revealedTargetCount: Int = 0
    @Published private(set) var awaitingNextAfterCorrect: Bool = false
    @Published private(set) var lastResultCorrect: Bool? = nil
    @Published var wrongFlashTrigger: Int = 0

    // Progress: each midi needs 2 correct.
    private let requiredCorrectPerNote: Int = 2
    private var correctCounts: [Int: Int] = [:]
    private var wrongNotes: Set<Int> = []

    init(level: EarTrainingLevel) {
        self.level = level
        newQuestion()
    }

    var allowedMidiNotes: [Int] {
        Array(level.midiRange)
    }

    func newQuestion() {
        awaitingNextAfterCorrect = false
        lastResultCorrect = nil
        inputMidi = []
        revealedTargetCount = 0

        var out: [Int] = []
        let pool = allowedMidiNotes
        let n = max(1, min(5, notesPerQuestion))
        for _ in 0..<n {
            out.append(pool[Int.random(in: 0..<pool.count)])
        }
        targetMidi = out.sorted() // low->high

        // Autoplay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.play()
        }
    }

    func play() {
        let seq = targetMidi
        for (i, midi) in seq.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.42) {
                PianoSoundEngine.shared.play(midi: midi)
            }
        }
    }

    func revealAnswer() {
        let total = targetMidi.count
        guard total > 0 else { return }
        revealedTargetCount = 0

        for i in 0..<total {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.42) { [weak self] in
                guard let self else { return }
                self.revealedTargetCount = min(total, i + 1)
                PianoSoundEngine.shared.play(midi: self.targetMidi[i])
            }
        }
    }

    func addInput(midi: Int) {
        guard !awaitingNextAfterCorrect else { return }
        guard inputMidi.count < targetMidi.count else { return }
        inputMidi.append(midi)
        PianoSoundEngine.shared.play(midi: midi)

        if inputMidi.count == targetMidi.count {
            confirm()
        }
    }

    func backspace() {
        guard !inputMidi.isEmpty else { return }
        inputMidi.removeLast()
    }

    func clear() {
        inputMidi = []
        lastResultCorrect = nil
        awaitingNextAfterCorrect = false
    }

    func confirm() {
        let ok = inputMidi.sorted() == targetMidi
        lastResultCorrect = ok

        if ok {
            incrementProgress(for: targetMidi)
            awaitingNextAfterCorrect = true
        } else {
            // record unique wrong notes (target notes that were missed)
            let inputSet = Set(inputMidi)
            for t in targetMidi where !inputSet.contains(t) {
                wrongNotes.insert(t)
            }

            wrongFlashTrigger &+= 1
            // show wrong notes briefly then clear and replay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { [weak self] in
                guard let self else { return }
                self.inputMidi = []
                self.lastResultCorrect = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                    self.play()
                }
            }
        }
    }

    func nextQuestion() {
        newQuestion()
    }

    private func incrementProgress(for midis: [Int]) {
        for m in midis {
            let cur = correctCounts[m] ?? 0
            correctCounts[m] = min(requiredCorrectPerNote, cur + 1)
        }
    }

    // points-based progress (changes every correct)
    var progressTotalPoints: Int {
        allowedMidiNotes.count * requiredCorrectPerNote
    }

    var progressPointsEarned: Int {
        allowedMidiNotes.reduce(0) { $0 + min(requiredCorrectPerNote, correctCounts[$1] ?? 0) }
    }

    var progressFraction: Double {
        guard progressTotalPoints > 0 else { return 0 }
        return Double(progressPointsEarned) / Double(progressTotalPoints)
    }

    var isLevelCompleted: Bool {
        progressPointsEarned >= progressTotalPoints
    }

    var completionAccuracy: Double {
        let total = max(1, allowedMidiNotes.count)
        let wrong = wrongNotes.count
        return max(0, 1.0 - (Double(wrong) / Double(total)))
    }

    func resetProgressOnEnter() {
        correctCounts = [:]
        wrongNotes = []
    }
}

// MARK: - Views

struct EarTrainingSelectionCard: View {
    @Binding var namingMode: NoteNamingMode
    @State private var selectedLevel: EarTrainingLevel? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZenCardHeader(
                title: "听音训练",
                subtitle: "练习听出音高并在键盘上作答",
                symbol: "ear"
            )
            ZenDivider()

            VStack(spacing: 10) {
                ForEach(EarTrainingLevel.library) { level in
                    Button(action: { selectedLevel = level }) {
                        EarLevelCardView(
                            level: level,
                            onStart: { selectedLevel = level }
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .cuteCard()
        .fullScreenCover(item: $selectedLevel) { level in
            EarTrainingView(level: level, namingMode: $namingMode)
        }
    }
}

struct EarLevelCardView: View {
    let level: EarTrainingLevel
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
                    Text("\(level.id)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(CuteTheme.textPrimary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(level.title)
                        .font(.system(size: CuteTheme.FontSize.body, weight: .semibold, design: .rounded))
                        .foregroundColor(CuteTheme.textPrimary)
                    Text(level.clefMode.titleKey)
                        .font(.system(size: CuteTheme.FontSize.caption, weight: .regular, design: .rounded))
                        .foregroundColor(CuteTheme.textSecondary)
                }

                Spacer()

                ZenMetaTag {
                    Text(level.clefMode.titleKey)
                }
            }

            Button(action: onStart) {
                Text("开始")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ZenActionButtonStyle())
        }
        .padding(18)
        .cuteCard()
    }
}

struct EarTrainingView: View {
    let level: EarTrainingLevel
    @Binding var namingMode: NoteNamingMode
    @StateObject private var viewModel: EarTrainingViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var showSettings: Bool = false

    init(level: EarTrainingLevel, namingMode: Binding<NoteNamingMode>) {
        self.level = level
        _namingMode = namingMode
        _viewModel = StateObject(wrappedValue: EarTrainingViewModel(level: level))
    }

    var body: some View {
        VStack(spacing: 10) {
            topBar

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Button("播放") { viewModel.play() }
                        .buttonStyle(SecondaryButtonStyle())
                    Button("显示答案") { viewModel.revealAnswer() }
                        .buttonStyle(SecondaryButtonStyle())

                    if viewModel.awaitingNextAfterCorrect, viewModel.lastResultCorrect == true {
                        Button("下一题") { viewModel.nextQuestion() }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                }

                ControlCard {
                    NamingModePicker(namingMode: $namingMode)
                }

                HStack(spacing: 8) {
                    Text("一次听几个音")
                        .font(.custom("AvenirNext-Regular", size: CuteTheme.FontSize.caption))
                        .foregroundColor(CuteTheme.textSecondary)
                    Spacer()
                    ForEach([1,2,3,4,5], id: \ .self) { n in
                        Button(action: { viewModel.notesPerQuestion = n; viewModel.newQuestion() }) {
                            Text("\(n)")
                                .font(.custom("AvenirNext-DemiBold", size: CuteTheme.FontSize.caption))
                                .foregroundColor(viewModel.notesPerQuestion == n ? .white : CuteTheme.textPrimary)
                                .frame(width: 28, height: 26)
                                .background(viewModel.notesPerQuestion == n ? CuteTheme.accent : CuteTheme.controlFill)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }

                progressCard

                EarTrainingStaffCard(
                    clefMode: level.clefMode,
                    targetMidi: viewModel.targetMidi,
                    inputMidi: viewModel.inputMidi,
                    revealedTargetCount: viewModel.revealedTargetCount,
                    expectedCount: viewModel.targetMidi.count,
                    wrongFlashTrigger: viewModel.wrongFlashTrigger
                )
                .frame(height: 260)

                EarTrainingKeyboard(
                    namingMode: namingMode,
                    highlightedMidi: Set(viewModel.targetMidi.prefix(viewModel.revealedTargetCount)),
                    onTapMidi: { viewModel.addInput(midi: $0) }
                )
                // Fill remaining space, but clamp max height so it stays piano-like.
                .frame(minHeight: 220, maxHeight: 260)
                .layoutPriority(1)
                .padding(.horizontal, 12)

                Spacer(minLength: 30)

                HStack {
                    Button("⌫") { viewModel.backspace() }
                        .buttonStyle(SecondaryButtonStyle())
                    Button("清空") { viewModel.clear() }
                        .buttonStyle(SecondaryButtonStyle())
                }
            }
            .padding(.horizontal, 16)

            Spacer(minLength: 10)
        }
        .padding(.top, 10)
        .zenBackground()
        .onAppear {
            // Reset progress every time entering a level.
            viewModel.resetProgressOnEnter()
        }
        .sheet(isPresented: $showSettings) {
            AppSettingsSheetView()
        }
    }

    private var topBar: some View {
        ZStack {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
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

                Spacer()

                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
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
            }

            Text("听音训练")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(CuteTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 16)
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("完成进度")
                    .font(.custom("AvenirNext-DemiBold", size: CuteTheme.FontSize.caption))
                    .foregroundColor(CuteTheme.textPrimary)
                Spacer()
                Text("\(viewModel.progressPointsEarned)/\(viewModel.progressTotalPoints)")
                    .font(.custom("AvenirNext-Regular", size: CuteTheme.FontSize.caption))
                    .foregroundColor(CuteTheme.textSecondary)
            }
            ProgressView(value: viewModel.progressFraction)
                .tint(viewModel.isLevelCompleted ? CuteTheme.feedbackSuccess : CuteTheme.accent)

            if viewModel.isLevelCompleted {
                let pct = Int((viewModel.completionAccuracy * 100).rounded())
                Text("完成！正确率 \(pct)%（同一个音重复错误不累计）")
                    .font(.custom("AvenirNext-Regular", size: CuteTheme.FontSize.caption))
                    .foregroundColor(CuteTheme.textSecondary)
            } else {
                Text("每个音需正确2次")
                    .font(.custom("AvenirNext-Regular", size: CuteTheme.FontSize.caption))
                    .foregroundColor(CuteTheme.textSecondary)
            }
        }
        .padding(12)
        .background(CuteTheme.cardBackground)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(CuteTheme.cardBorder, lineWidth: 1)
        )
    }
}

struct EarTrainingStaffCard: View {
    let clefMode: StaffClefMode
    let targetMidi: [Int]
    let inputMidi: [Int]
    let revealedTargetCount: Int
    let expectedCount: Int
    let wrongFlashTrigger: Int

    @State private var wrongFlashOpacity: Double = 0

    var body: some View {
        GeometryReader { proxy in
            let layout = StaffLayout(size: proxy.size, mode: clefMode)
            let metrics = layout.single.metrics
            ZStack {
                // staff background
                StaffLinesView(metrics: metrics)

                let slots = max(1, expectedCount)
                let slotXs: [CGFloat] = (0..<slots).map { i in
                    let t = slots == 1 ? 0.5 : (CGFloat(i) / CGFloat(slots - 1))
                    return metrics.leftMargin + (metrics.rightMargin - metrics.leftMargin) * t
                }

                // revealed answers (green)
                ForEach(Array(targetMidi.prefix(revealedTargetCount).enumerated()), id: \ .offset) { idx, midi in
                    if let rendered = renderedNote(for: midi) {
                        ZStack {
                            NoteGlyphView(
                                note: rendered.note,
                                metrics: metrics,
                                xPosition: slotXs[min(idx, slotXs.count - 1)],
                                color: CuteTheme.judgementCorrect,
                                rhythm: .quarter
                            )
                            if rendered.showSharp {
                                Text("#")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(CuteTheme.judgementCorrect)
                                    .position(x: slotXs[min(idx, slotXs.count - 1)] - 18, y: metrics.y(for: rendered.note.index))
                            }
                        }
                        .zIndex(0)
                    }
                }

                // user input (blue)
                ForEach(Array(inputMidi.enumerated()), id: \ .offset) { idx, midi in
                    if let rendered = renderedNote(for: midi) {
                        ZStack {
                            NoteGlyphView(
                                note: rendered.note,
                                metrics: metrics,
                                xPosition: slotXs[min(idx, slotXs.count - 1)],
                                color: CuteTheme.accent,
                                rhythm: .quarter
                            )
                            if rendered.showSharp {
                                Text("#")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(CuteTheme.accent)
                                    .position(x: slotXs[min(idx, slotXs.count - 1)] - 18, y: metrics.y(for: rendered.note.index))
                            }
                        }
                        .zIndex(2)
                    }
                }

                Rectangle()
                    .fill(CuteTheme.judgementWrong.opacity(wrongFlashOpacity))
                    .cornerRadius(20)
                    .allowsHitTesting(false)
            }
        }
        .padding(12)
        .background(CuteTheme.cardBackground)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(CuteTheme.cardBorder, lineWidth: 1)
        )
        .onChange(of: wrongFlashTrigger) { _ in
            wrongFlashOpacity = 0
            withAnimation(.easeOut(duration: 0.12)) { wrongFlashOpacity = 0.25 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                withAnimation(.easeOut(duration: 0.12)) { wrongFlashOpacity = 0 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                withAnimation(.easeOut(duration: 0.12)) { wrongFlashOpacity = 0.25 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
                withAnimation(.easeOut(duration: 0.12)) { wrongFlashOpacity = 0 }
            }
        }
    }

    private struct RenderedNote {
        let note: StaffNote
        let showSharp: Bool
    }

    private func renderedNote(for midi: Int) -> RenderedNote? {
        // Snap to closest natural StaffNote; show # if it's a semitone above.
        let pools: [StaffNote]
        switch clefMode {
        case .treble:
            pools = StaffNote.all(for: StaffClef.treble)
        case .bass:
            pools = StaffNote.all(for: StaffClef.bass)
        case .grand:
            let mid = 60
            pools = StaffNote.all(for: midi >= mid ? StaffClef.treble : StaffClef.bass)
        }
        guard let nearest = pools.min(by: { abs($0.midiNoteNumber - midi) < abs($1.midiNoteNumber - midi) }) else { return nil }

        let delta = midi - nearest.midiNoteNumber
        let showSharp = (delta == 1)
        return RenderedNote(note: nearest, showSharp: showSharp)
    }
}


struct EarTrainingKeyboard: View {
    let namingMode: NoteNamingMode
    let highlightedMidi: Set<Int>
    let onTapMidi: (Int) -> Void

    // One octave starting at C4.
    private let baseMidi: Int = 60

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let whiteCount: CGFloat = 7
            let whiteW = w / whiteCount
            let blackW = whiteW * 0.72
            let blackH = h * 0.64

            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \ .self) { i in
                        let midi = baseMidi + whiteMidiOffsets[i]
                        KeyButton(
                            label: whiteLabel(i),
                            isBlack: false,
                            isHighlighted: highlightedMidi.contains(midi),
                            action: { onTapMidi(midi) }
                        )
                        .frame(width: whiteW, height: h)
                    }
                }

                ForEach(blackKeys.indices, id: \ .self) { idx in
                    let bk = blackKeys[idx]
                    let x = (CGFloat(bk.whiteIndex) + 1) * whiteW - blackW / 2
                    let midi = baseMidi + bk.midiOffset
                    KeyButton(
                        label: blackLabel(bk.pitchClass),
                        isBlack: true,
                        isHighlighted: highlightedMidi.contains(midi),
                        action: { onTapMidi(midi) }
                    )
                    .frame(width: blackW, height: blackH)
                    // Use offset (top-left anchored) to avoid position hit-test quirks.
                    .offset(x: x, y: 0)
                    .zIndex(10)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(CuteTheme.controlBorder, lineWidth: 1)
        )
    }

    private var whiteMidiOffsets: [Int] { [0, 2, 4, 5, 7, 9, 11] }

    private struct BlackKey {
        let whiteIndex: Int
        let midiOffset: Int
        let pitchClass: Int
    }

    private var blackKeys: [BlackKey] {
        [
            BlackKey(whiteIndex: 0, midiOffset: 1, pitchClass: 1),
            BlackKey(whiteIndex: 1, midiOffset: 3, pitchClass: 3),
            BlackKey(whiteIndex: 3, midiOffset: 6, pitchClass: 6),
            BlackKey(whiteIndex: 4, midiOffset: 8, pitchClass: 8),
            BlackKey(whiteIndex: 5, midiOffset: 10, pitchClass: 10)
        ]
    }

    private func whiteLabel(_ index: Int) -> String {
        let letters: [NoteLetter] = [.c, .d, .e, .f, .g, .a, .b]
        return letters[index].displayName(for: namingMode)
    }

    private func blackLabel(_ pitchClass: Int) -> String {
        // pitchClass is midi%12 for sharps.
        if namingMode == .solfege {
            switch pitchClass {
            case 1: return "Do#"
            case 3: return "Re#"
            case 6: return "Fa#"
            case 8: return "Sol#"
            case 10: return "La#"
            default: return "#"
            }
        }
        switch pitchClass {
        case 1: return "C#"
        case 3: return "D#"
        case 6: return "F#"
        case 8: return "G#"
        case 10: return "A#"
        default: return "#"
        }
    }

    private struct KeyButton: View {
        let label: String
        let isBlack: Bool
        let isHighlighted: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                ZStack {
                    Rectangle()
                        .fill(isBlack ? CuteTheme.textPrimary : Color.white)

                    if isHighlighted {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(CuteTheme.judgementCorrect, lineWidth: isBlack ? 2 : 3)
                            .shadow(color: CuteTheme.judgementCorrect.opacity(0.35), radius: 6)
                            .padding(isBlack ? 2 : 3)
                    }

                    Text(label)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(isBlack ? Color.white : CuteTheme.textPrimary)
                        .padding(.bottom, 6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        }
    }
}
