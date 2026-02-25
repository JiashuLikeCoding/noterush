import SwiftUI
import AVFoundation
import Combine
import UIKit

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
        EarTrainingLevel(id: 1, title: "高音谱", clefMode: .treble, midiRange: 57...84), // A3..C6
        EarTrainingLevel(id: 2, title: "低音谱", clefMode: .bass, midiRange: 36...64),   // C2..E4
        EarTrainingLevel(id: 3, title: "高低音谱", clefMode: .grand, midiRange: 36...84) // C2..C6
    ]
}

// MARK: - Audio (piano-ish)

final class PianoSoundEngine {
    static let shared = PianoSoundEngine()

    private let engine = AVAudioEngine()
    private let sampler = AVAudioUnitSampler()
    private var didStart = false
    private var tempSF2URL: URL?

    private init() {
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)
    }

    private func writeTempSF2IfNeeded(data: Data) -> URL? {
        // AVAudioUnitSampler expects a file URL. If the soundfont is packaged as a Data Asset,
        // we need to write it to a temp location first.
        if let url = tempSF2URL, FileManager.default.fileExists(atPath: url.path) {
            return url
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("soundfont.sf2")
        do {
            try data.write(to: url, options: [.atomic])
            tempSF2URL = url
            return url
        } catch {
            return nil
        }
    }

    func startIfNeeded() {
        guard !didStart else { return }

        // Load instrument FIRST (this is usually the source of the first-tap hitch).
        // Prefer bundled soundfont if present.
        // Note: In this project, the soundfont is stored in Assets.xcassets as a Data Set,
        // which is accessed via NSDataAsset.
        if let asset = NSDataAsset(name: "soundfont"),
           let sf2 = writeTempSF2IfNeeded(data: asset.data) {
            try? sampler.loadSoundBankInstrument(
                at: sf2,
                program: 0,
                bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                bankLSB: 0
            )
        } else {
            // Fallback:
            // - On macOS Simulator / macOS, we may have a system GM DLS.
            // - On iOS devices, that path usually doesn't exist; still select program 0 (Acoustic Grand)
            //   in the default melodic bank so we get a piano-ish timbre instead of a beep.
            #if targetEnvironment(simulator)
            let url = URL(fileURLWithPath: "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls")
            if FileManager.default.fileExists(atPath: url.path) {
                try? sampler.loadSoundBankInstrument(
                    at: url,
                    program: 0,
                    bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                    bankLSB: 0
                )
            }
            #endif

            sampler.sendProgramChange(
                0,
                bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                bankLSB: 0,
                onChannel: 0
            )
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
    // Prevent overlapping scheduled playback (Play vs Reveal) from cutting each other off.
    private var playbackToken: Int = 0
    @Published private(set) var level: EarTrainingLevel
    @Published var notesPerQuestion: Int = 1

    // Keyboard: always 1 octave, but the octave will shift per-question to match targets.
    @Published private(set) var keyboardBaseMidi: Int = 60 // C4

    // Targets + playback are the same pitches (kept within one octave window).
    @Published private(set) var targetMidi: [Int] = []
    @Published private(set) var targetPlaybackMidi: [Int] = []

    @Published private(set) var inputMidi: [Int] = []

    @Published private(set) var revealedTargetCount: Int = 0

    // If the user revealed the answer for the current question, do NOT award progress points.
    private var didRevealAnswerThisQuestion: Bool = false

    // Key flashing while revealing answer (supports duplicates)
    @Published private(set) var revealPulseMidi: Int? = nil
    @Published private(set) var revealPulseToken: Int = 0
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
        revealPulseMidi = nil
        didRevealAnswerThisQuestion = false

        let n = max(1, min(5, notesPerQuestion))

        // Keep each question within ONE octave, and shift the on-screen keyboard octave to match.
        let window = pickOneOctaveWindow()
        keyboardBaseMidi = window.lowerBound

        let poolInWindow = Array(window)
        var clipped: [Int] = []

        // Prefer NO duplicates within a question.
        // (The user reported "连续2个一样的音"; this eliminates adjacent duplicates and also keeps the question more varied.)
        func appendUnique(from candidates: [Int]) {
            let used = Set(clipped)
            let available = candidates.filter { !used.contains($0) }
            if let pick = available.randomElement() {
                clipped.append(pick)
            } else if let fallback = candidates.randomElement() {
                clipped.append(fallback)
            }
        }

        // For grand staff, try to include BOTH clefs in the same question when possible.
        // (Some notes < 60 show on bass, some >= 60 show on treble.)
        if level.clefMode == .grand, n >= 2 {
            let lowPool = poolInWindow.filter { $0 < 60 }
            let highPool = poolInWindow.filter { $0 >= 60 }

            if !lowPool.isEmpty, !highPool.isEmpty {
                appendUnique(from: lowPool)
                appendUnique(from: highPool)
                while clipped.count < n {
                    appendUnique(from: poolInWindow)
                }
            } else {
                while clipped.count < n {
                    appendUnique(from: poolInWindow)
                }
            }
        } else {
            while clipped.count < n {
                appendUnique(from: poolInWindow)
            }
        }

        // Randomize playback order (not always low->high).
        targetMidi = clipped
        targetPlaybackMidi = clipped.shuffled()

        // Autoplay (faster; user feedback: 2s felt too long)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.play()
        }
    }

    func play() {
        // Start a fresh playback sequence; older scheduled callbacks become no-ops.
        playbackToken &+= 1
        let token = playbackToken

        let seq = targetPlaybackMidi
        let step: TimeInterval = 1.0
        for (i, midi) in seq.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * step) { [weak self] in
                guard let self else { return }
                guard self.playbackToken == token else { return }
                PianoSoundEngine.shared.play(midi: midi)
            }
        }
    }

    func revealAnswer() {
        // Revealing the answer makes this question "practice only" (no progress credit).
        didRevealAnswerThisQuestion = true

        // Always clear user input when revealing the answer.
        inputMidi = []
        lastResultCorrect = nil
        awaitingNextAfterCorrect = false

        let total = targetPlaybackMidi.count
        guard total > 0 else { return }
        revealedTargetCount = 0

        // Start a fresh playback sequence; older scheduled callbacks become no-ops.
        playbackToken &+= 1
        let token = playbackToken

        let step: TimeInterval = 1.0
        for i in 0..<total {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * step) { [weak self] in
                guard let self else { return }
                guard self.playbackToken == token else { return }

                self.revealedTargetCount = min(total, i + 1)

                // Flash the key for THIS step (even if the midi repeats).
                let midi = self.targetPlaybackMidi[i]
                self.revealPulseMidi = midi
                self.revealPulseToken &+= 1

                PianoSoundEngine.shared.play(midi: midi)
            }
        }
    }

    func addInput(midi: Int) {
        guard !awaitingNextAfterCorrect else { return }
        guard inputMidi.count < targetMidi.count else { return }
        inputMidi.append(midi)

        // Play what the user tapped (keyboard octave)
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
        // IMPORTANT: In LISTEN, the keyboard is a single octave, while the staff (especially GRAND)
        // can render the same pitch class in a different octave.
        // So correctness should be judged by pitch class multiset (ignore octave),
        // ensuring keyboard position + heard pitch class match the answer.
        func pcs(_ arr: [Int]) -> [Int] {
            arr.map { (($0 % 12) + 12) % 12 }.sorted()
        }

        let ok = pcs(inputMidi) == pcs(targetMidi)
        lastResultCorrect = ok

        // Records (LISTEN). User requested: record final correct/incorrect regardless of "显示答案".
        RecordsStore.shared.logAnswer(mode: .listen, correct: ok)

        if ok {
            if !didRevealAnswerThisQuestion {
                incrementProgress(for: targetMidi)
            }
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
                // Replay after a short pause (faster; user feedback: interval felt too long)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
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

    private func pickOneOctaveWindow() -> ClosedRange<Int> {
        // Choose a 12-semitone window fully inside the level range.
        // Default: step by octaves so the keyboard base stays musically familiar (C-based windows).
        // Grand staff special-case: prefer a window that STRADDLES middle C (60), so questions can
        // contain both bass (<60) and treble (>=60) notes.
        let lo = level.midiRange.lowerBound
        let hi = level.midiRange.upperBound
        if hi - lo <= 11 {
            return lo...hi
        }

        let startMin = lo
        let startMax = hi - 11

        if level.clefMode == .grand {
            // Prefer any window where lowerBound < 60 <= upperBound.
            // This may not be C-aligned; that's ok for this level.
            let preferredStarts = Array(startMin...startMax).filter { s in
                let e = s + 11
                return s < 60 && e >= 60
            }
            if !preferredStarts.isEmpty {
                let start = preferredStarts[Int.random(in: 0..<preferredStarts.count)]
                return start...(start + 11)
            }
            // Fallback to C-aligned starts.
        }

        // Align starts to C of an octave.
        var starts: [Int] = []
        let firstC = (startMin / 12) * 12
        var s = firstC
        while s <= startMax {
            if s >= startMin { starts.append(s) }
            s += 12
        }
        if starts.isEmpty {
            // Fallback: any start that fits.
            return startMin...(startMin + 11)
        }
        let start = starts[Int.random(in: 0..<starts.count)]
        return start...(start + 11)
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
        JellyCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("LISTEN")
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundColor(KidTheme.textOnCardPrimary)
                        Text("听音训练")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(KidTheme.textOnCardSecondary)
                    }

                    Spacer()

                    Image(systemName: "ear")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundColor(KidTheme.primary)
                        .padding(10)
                        .background(KidTheme.primary.opacity(0.12))
                        .cornerRadius(14)
                }

                VStack(spacing: 12) {
                    ForEach(EarTrainingLevel.library) { level in
                        EarLevelCardView(
                            level: level,
                            onStart: { selectedLevel = level }
                        )
                    }
                }
            }
        }
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
                        .fill(Color.black.opacity(0.04))
                        .frame(width: 44, height: 44)
                    Text("L\(level.id)")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(KidTheme.textOnCardPrimary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(level.title)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(KidTheme.textOnCardPrimary)
                    Text(level.clefMode.titleKey)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(KidTheme.textOnCardSecondary)
                }

                Spacer()

                JellyPill(text: level.clefMode.titleKey, tint: KidTheme.accent)
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
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.10), radius: 16, x: 0, y: 10)
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
            ListenNavigationBar(
                onBack: { dismiss() },
                onOpenSettings: { showSettings = true }
            )

            VStack(spacing: 12) {
                // Controls (compact; no scrolling)
                CompactJellyCard {
                    VStack(spacing: 10) {
                            HStack(spacing: 10) {
                                Button("播放") { viewModel.play() }
                                    .buttonStyle(JellyTintButtonStyle(tint: KidTheme.primary))

                                Button("显示答案") { viewModel.revealAnswer() }
                                    .buttonStyle(JellyTintButtonStyle(tint: KidTheme.accent))

                                if viewModel.awaitingNextAfterCorrect, viewModel.lastResultCorrect == true {
                                    Button("下一题") { viewModel.nextQuestion() }
                                        .buttonStyle(JellyTintButtonStyle(tint: KidTheme.success))
                                }
                            }

                            NamingModePicker(namingMode: $namingMode)

                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("一次听几个音")
                                        .font(.system(size: KidTheme.FontSize.caption, weight: .semibold, design: .rounded))
                                        .foregroundColor(KidTheme.textOnCardPrimary)
                                    Text("1–5 个")
                                        .font(.system(size: KidTheme.FontSize.tiny, weight: .medium, design: .rounded))
                                        .foregroundColor(KidTheme.textOnCardSecondary)
                                }

                                Spacer()

                                HStack(spacing: 8) {
                                    ForEach([1,2,3,4,5], id: \ .self) { n in
                                        let isSelected = viewModel.notesPerQuestion == n
                                        Button(action: {
                                            viewModel.notesPerQuestion = n
                                            viewModel.newQuestion()
                                        }) {
                                            Text("\(n)")
                                                .font(.system(size: KidTheme.FontSize.caption, weight: .heavy, design: .rounded))
                                                .foregroundColor(isSelected ? .white : KidTheme.textOnCardPrimary)
                                                .frame(width: 34, height: 34)
                                                .background(isSelected ? KidTheme.primary : KidTheme.surface)
                                                .cornerRadius(12)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(KidTheme.border, lineWidth: 1)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }

                            progressKidCard
                        }
                }

                CompactJellyCard {
                    EarTrainingStaffCard(
                        clefMode: level.clefMode,
                        targetMidi: viewModel.targetPlaybackMidi,
                        inputMidi: viewModel.inputMidi,
                        revealedTargetCount: viewModel.revealedTargetCount,
                        expectedCount: viewModel.targetMidi.count,
                        wrongFlashTrigger: viewModel.wrongFlashTrigger
                    )
                    .frame(height: 210)
                }

                CompactJellyCard {
                    VStack(spacing: 10) {
                        EarTrainingKeyboard(
                            namingMode: namingMode,
                            baseMidi: viewModel.keyboardBaseMidi,
                            revealedMidi: Set(viewModel.targetPlaybackMidi.prefix(viewModel.revealedTargetCount)),
                            pulseMidi: viewModel.revealPulseMidi,
                            pulseToken: viewModel.revealPulseToken,
                            onTapMidi: { viewModel.addInput(midi: $0) }
                        )
                        .frame(height: 220)

                        HStack(spacing: 12) {
                            Button("⌫") { viewModel.backspace() }
                                .buttonStyle(JellyButtonStyle(kind: .secondary))
                            Button("清空") { viewModel.clear() }
                                .buttonStyle(JellyButtonStyle(kind: .secondary))
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 18)
        }
        .kidBackground()
        .recordSession(mode: .listen)
        .onAppear {
            // Reset progress every time entering a level.
            viewModel.resetProgressOnEnter()
        }
        .sheet(isPresented: $showSettings) {
            AppSettingsSheetView()
        }
    }

    private var progressKidCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PROGRESS")
                        .font(.system(size: KidTheme.FontSize.caption, weight: .heavy, design: .rounded))
                        .foregroundColor(KidTheme.textPrimary)
                    Text("完成进度")
                        .font(.system(size: KidTheme.FontSize.tiny, weight: .semibold, design: .rounded))
                        .foregroundColor(KidTheme.textSecondary)
                }

                Spacer()

                Text("\(viewModel.progressPointsEarned)/\(viewModel.progressTotalPoints)")
                    .font(.system(size: KidTheme.FontSize.caption, weight: .semibold, design: .rounded))
                    .foregroundColor(KidTheme.textSecondary)
            }

            ProgressView(value: viewModel.progressFraction)
                .tint(viewModel.isLevelCompleted ? KidTheme.success : KidTheme.primary)

            if viewModel.isLevelCompleted {
                let pct = Int((viewModel.completionAccuracy * 100).rounded())
                Text("完成！正确率 \(pct)%")
                    .font(.system(size: KidTheme.FontSize.caption, weight: .semibold, design: .rounded))
                    .foregroundColor(KidTheme.textSecondary)
            } else {
                Text("每个音需正确 2 次")
                    .font(.system(size: KidTheme.FontSize.caption, weight: .medium, design: .rounded))
                    .foregroundColor(KidTheme.textSecondary)
            }
        }
    }
}

private struct CompactJellyCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: KidTheme.Radius.card)
                .fill(KidTheme.surface)
                .overlay(
                    LinearGradient(
                        colors: [Color.white.opacity(0.22), Color.white.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: KidTheme.Radius.card))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: KidTheme.Radius.card)
                        .stroke(KidTheme.border, lineWidth: 1)
                )
                .shadow(color: KidTheme.shadow.opacity(0.85), radius: 14, x: 0, y: 10)

            content
                .padding(12)
        }
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

    // Clef fly-away intro (requested): after 1s, fly to top-right and shrink.
    @State private var clefCollapsed: Bool = false
    // Notes appear after the clef animation finishes (another 1s).
    @State private var showNotes: Bool = false

    var body: some View {
        GeometryReader { proxy in
            let layout = StaffLayout(size: proxy.size, mode: clefMode)
            let slots = max(1, expectedCount)

            ZStack {
                // Staff background (lines)
                if clefMode == .grand {
                    if let treble = layout.treble {
                        StaffLinesView(metrics: treble.metrics)
                            .offset(y: treble.yOffset)
                            .zIndex(0)
                    }
                    if let bass = layout.bass {
                        StaffLinesView(metrics: bass.metrics)
                            .offset(y: bass.yOffset)
                            .zIndex(0)
                    }
                } else {
                    StaffLinesView(metrics: layout.single.metrics)
                        .zIndex(0)
                }

                // Clef fly-away intro
                clefIconsOverlay(in: proxy.size, layout: layout)
                    .zIndex(-1)

                // slot positions across the staff width
                let metricsForSlots = layout.single.metrics
                let slotXs: [CGFloat] = (0..<slots).map { i in
                    let t = slots == 1 ? 0.5 : (CGFloat(i) / CGFloat(slots - 1))
                    return metricsForSlots.leftMargin + (metricsForSlots.rightMargin - metricsForSlots.leftMargin) * t
                }

                if showNotes {
                    // revealed answers
                    ForEach(Array(targetMidi.prefix(revealedTargetCount).enumerated()), id: \ .offset) { idx, midi in
                        if let rendered = renderedNote(for: midi) {
                            let slot = layout.slot(for: rendered.note.clef)
                            let x = slotXs[min(idx, slotXs.count - 1)]
                            let answerColor = listenAnswerHighlightColor(for: midi)
                            ZStack {
                                NoteGlyphView(
                                    note: rendered.note,
                                    metrics: slot.metrics,
                                    xPosition: x,
                                    color: answerColor,
                                    rhythm: .quarter,
                                    yOffset: slot.yOffset
                                )
                                if rendered.showSharp {
                                    Text("#")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(answerColor)
                                        .position(x: x - 18, y: slot.metrics.y(for: rendered.note.index) + slot.yOffset)
                                }
                            }
                            .zIndex(1)
                        }
                    }

                    // user input
                    ForEach(Array(inputMidi.enumerated()), id: \ .offset) { idx, midi in
                        if let rendered = renderedNote(for: midi) {
                            let slot = layout.slot(for: rendered.note.clef)
                            let x = slotXs[min(idx, slotXs.count - 1)]
                            let inputColor = KidTheme.userInput
                            ZStack {
                                NoteGlyphView(
                                    note: rendered.note,
                                    metrics: slot.metrics,
                                    xPosition: x,
                                    color: inputColor,
                                    rhythm: .quarter,
                                    yOffset: slot.yOffset
                                )
                                if rendered.showSharp {
                                    Text("#")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(inputColor)
                                        .position(x: x - 18, y: slot.metrics.y(for: rendered.note.index) + slot.yOffset)
                                }
                            }
                            .zIndex(2)
                        }
                    }
                }

                Rectangle()
                    .fill(CuteTheme.judgementWrong.opacity(wrongFlashOpacity))
                    .cornerRadius(KidTheme.Radius.card)
                    .allowsHitTesting(false)
                    .zIndex(20)
            }
        }
        // Note: this view is wrapped by CompactJellyCard already.
        // Do not add another card background here (it looks like a double-layer card).
        .onAppear {
            // Start intro timeline: 1s -> clef flies to the top-right, then wait 1s -> notes appear.
            clefCollapsed = false
            showNotes = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.88)) {
                    clefCollapsed = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                withAnimation(.easeOut(duration: 0.18)) {
                    showNotes = true
                }
            }
        }
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

    private func clefIconsOverlay(in size: CGSize, layout: StaffLayout) -> some View {
        // Collapsed target positions (top-right)
        let collapsedX = size.width - 22

        func clefIcon(_ clef: StaffClef, metrics: StaffMetrics, yOffset: CGFloat, collapsedIndex: Int) -> some View {
            let assetName = clef == .treble ? "high" : "low"
            let iconSize = metrics.lineSpacing * 7.8

            // Default (full-size) position matching old ClefIconView
            let minX = iconSize * 0.45
            let defaultX = max(minX, metrics.leftMargin - metrics.lineSpacing * 1.2)
            let defaultY = (metrics.y(for: metrics.topStaffLineIndex) + metrics.y(for: metrics.bottomStaffLineIndex)) / 2 + yOffset

            // In GRAND mode, each clef belongs to its own staff slot; yOffset places the slot.
            // So the collapsed icon should sit in the top-right corner of *that slot*.
            let collapsedY = yOffset + 24

            return Image(assetName)
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .opacity(CuteTheme.clefOpacity)
                .scaleEffect(clefCollapsed ? 0.44 : 1.0, anchor: .center)
                .position(x: clefCollapsed ? collapsedX : defaultX,
                          y: clefCollapsed ? collapsedY : defaultY)
        }

        return ZStack {
            switch clefMode {
            case .grand:
                if let treble = layout.treble {
                    clefIcon(.treble, metrics: treble.metrics, yOffset: treble.yOffset, collapsedIndex: 0)
                }
                if let bass = layout.bass {
                    clefIcon(.bass, metrics: bass.metrics, yOffset: bass.yOffset, collapsedIndex: 1)
                }
            case .bass:
                clefIcon(.bass, metrics: layout.single.metrics, yOffset: 0, collapsedIndex: 0)
            case .treble:
                clefIcon(.treble, metrics: layout.single.metrics, yOffset: 0, collapsedIndex: 0)
            }
        }
        .allowsHitTesting(false)
    }

    private struct RenderedNote {
        let note: StaffNote
        let showSharp: Bool
    }

    private func renderedNote(for midi: Int) -> RenderedNote? {
        // Render pitches in a way that always matches the keyboard:
        // - Natural notes (white keys) must NEVER show a sharp.
        // - Accidentals are represented only as sharps (#), i.e. black keys = lower natural + #.

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

        let pc = ((midi % 12) + 12) % 12
        let isSharpPc: Bool = [1, 3, 6, 8, 10].contains(pc)

        // Pick a base natural staff note by pitch class (and closest register).
        let basePc = isSharpPc ? ((pc + 11) % 12) : pc // sharp -> previous natural
        let candidates = pools.filter { ((($0.midiNoteNumber % 12) + 12) % 12) == basePc }

        // If we can't find a matching pitch class in this clef pool, fall back.
        let base: StaffNote?
        if let nearestSamePc = candidates.min(by: { abs($0.midiNoteNumber - midi) < abs($1.midiNoteNumber - midi) }) {
            base = nearestSamePc
        } else {
            base = pools.min(by: { abs($0.midiNoteNumber - midi) < abs($1.midiNoteNumber - midi) })
        }

        guard let base else { return nil }
        return RenderedNote(note: base, showSharp: isSharpPc)
    }
}


fileprivate func listenAnswerHighlightColor(for midi: Int) -> Color {
    // Answer colors must be HIGH-CONTRAST on a light staff card, and MUST NOT use purple
    // (purple is reserved for user input). Also keep colors far apart so adjacent notes
    // don't look too similar.
    // Use pitch class mapping so any octave still looks consistent.
    switch ((midi % 12) + 12) % 12 {
    case 0:  return Color(red: 0.92, green: 0.18, blue: 0.22) // C  - red
    case 1:  return Color(red: 0.98, green: 0.20, blue: 0.55) // C# - hot pink (not purple)
    case 2:  return Color(red: 0.98, green: 0.44, blue: 0.10) // D  - orange
    case 3:  return Color(red: 0.55, green: 0.30, blue: 0.08) // D# - brown (very distinct)
    case 4:  return Color(red: 0.88, green: 0.66, blue: 0.08) // E  - amber/gold
    case 5:  return Color(red: 0.10, green: 0.62, blue: 0.26) // F  - green
    case 6:  return Color(red: 0.06, green: 0.70, blue: 0.72) // F# - cyan
    case 7:  return Color(red: 0.10, green: 0.42, blue: 0.95) // G  - blue
    case 8:  return Color(red: 0.02, green: 0.56, blue: 0.36) // G# - teal-green (avoid blue overlap)
    case 9:  return Color(red: 0.12, green: 0.22, blue: 0.78) // A  - navy (separated from G)
    case 10: return Color(red: 0.36, green: 0.78, blue: 0.08) // A# - lime
    case 11: return Color(red: 0.90, green: 0.30, blue: 0.06) // B  - vermillion
    default:
        return Color.white
    }
}

struct EarTrainingKeyboard: View {
    let namingMode: NoteNamingMode
    let baseMidi: Int
    let revealedMidi: Set<Int>
    let pulseMidi: Int?
    let pulseToken: Int
    let onTapMidi: (Int) -> Void

    @State private var pressedId: String? = nil

    // One octave C..B
    private let whiteLetters: [NoteLetter] = [.c, .d, .e, .f, .g, .a, .b]

    private struct BlackKey {
        let afterWhiteIndex: Int // black key sits after this white key
        let labelLetters: String
        let labelSolfege: String
        let midi: Int
    }

    // C#, D#, F#, G#, A#
    private var blackKeys: [BlackKey] {
        [
            BlackKey(afterWhiteIndex: 0, labelLetters: "C#", labelSolfege: "Do#", midi: baseMidi + 1),
            BlackKey(afterWhiteIndex: 1, labelLetters: "D#", labelSolfege: "Re#", midi: baseMidi + 3),
            BlackKey(afterWhiteIndex: 3, labelLetters: "F#", labelSolfege: "Fa#", midi: baseMidi + 6),
            BlackKey(afterWhiteIndex: 4, labelLetters: "G#", labelSolfege: "Sol#", midi: baseMidi + 8),
            BlackKey(afterWhiteIndex: 5, labelLetters: "A#", labelSolfege: "La#", midi: baseMidi + 10),
        ]
    }

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            let gap: CGFloat = 2
            let whiteCount = CGFloat(whiteLetters.count)
            let whiteW = (w - gap * (whiteCount - 1)) / whiteCount
            let blackW = whiteW * 0.62
            let blackH = h * 0.58

            ZStack(alignment: .topLeading) {
                // White keys
                HStack(spacing: gap) {
                    ForEach(whiteLetters.indices, id: \ .self) { i in
                        let letter = whiteLetters[i]
                        let midi = midiForWhite(letter)

                        EarPianoTouchKey(
                            id: "w_\(letter.rawValue)",
                            width: whiteW,
                            height: h,
                            pressedId: $pressedId,
                            onTrigger: { onTapMidi(midi) }
                        ) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white)

                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.black.opacity(0.12), lineWidth: 1)

                                let answerColor = listenAnswerHighlightColor(for: midi)
                                if revealedMidi.contains(midi) {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(answerColor.opacity(0.22))
                                        .padding(2)

                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(answerColor.opacity(0.95), lineWidth: 3)
                                        .padding(2)
                                        .shadow(color: answerColor.opacity(0.25), radius: 10)
                                }

                                // Pulse highlight (supports duplicates by using pulseToken)
                                if pulseMidi == midi {
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(answerColor, lineWidth: 4)
                                        .shadow(color: answerColor.opacity(0.45), radius: 14)
                                        .padding(2)
                                        .transition(.opacity)
                                        .id("pulse_w_\(midi)_\(pulseToken)")
                                }

                                Text(letter.displayName(for: namingMode))
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(CuteTheme.textPrimary)
                                    .padding(.bottom, 32)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                                    .background(Color.white.opacity(0.0001))
                            }
                        }
                    }
                }

                // Black keys
                ForEach(blackKeys.indices, id: \ .self) { idx in
                    let bk = blackKeys[idx]
                    let boundaryX = (CGFloat(bk.afterWhiteIndex) + 1) * (whiteW + gap) - gap / 2
                    let x = boundaryX - blackW / 2

                    EarPianoTouchKey(
                        id: "b_\(bk.labelLetters)",
                        width: blackW,
                        height: blackH,
                        pressedId: $pressedId,
                        onTrigger: { onTapMidi(bk.midi) }
                    ) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.95))
                                .shadow(color: Color.black.opacity(0.25), radius: 5, x: 0, y: 3)

                            let answerColor = listenAnswerHighlightColor(for: bk.midi)
                            if revealedMidi.contains(bk.midi) {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(answerColor.opacity(0.95), lineWidth: 3)
                                    .padding(2)
                                    .shadow(color: answerColor.opacity(0.35), radius: 12)
                            }

                            if pulseMidi == bk.midi {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(answerColor, lineWidth: 4)
                                    .shadow(color: answerColor.opacity(0.55), radius: 16)
                                    .padding(2)
                                    .transition(.opacity)
                                    .id("pulse_b_\(bk.midi)_\(pulseToken)")
                            }

                            Text(namingMode == .letters ? bk.labelLetters : bk.labelSolfege)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(Color.white)
                                .padding(.bottom, 20)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        }
                    }
                    .offset(x: x, y: 0)
                    .zIndex(10)
                }
            }
        }
    }

    private func midiForWhite(_ letter: NoteLetter) -> Int {
        switch letter {
        case .c: return baseMidi + 0
        case .d: return baseMidi + 2
        case .e: return baseMidi + 4
        case .f: return baseMidi + 5
        case .g: return baseMidi + 7
        case .a: return baseMidi + 9
        case .b: return baseMidi + 11
        }
    }

}

struct ListenNavigationBar: View {
    let onBack: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        ZStack {
            HStack(spacing: 12) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(KidTheme.surfaceStrong)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(KidTheme.border, lineWidth: 1)
                        )
                }
                .foregroundColor(KidTheme.textOnBackgroundPrimary)

                Spacer()

                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(KidTheme.surfaceStrong)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(KidTheme.border, lineWidth: 1)
                        )
                }
                .foregroundColor(KidTheme.textOnBackgroundPrimary)
            }

            Text("LISTEN")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(KidTheme.textOnBackgroundPrimary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }
}

private struct EarPianoTouchKey<Content: View>: View {
    let id: String
    let width: CGFloat
    let height: CGFloat
    @Binding var pressedId: String?
    let onTrigger: () -> Void
    @ViewBuilder let content: () -> Content

    // NOTE: Using DragGesture(minDistance:0) for immediate response.
    // We only fire when `pressedId` changes to this key, and we also schedule a short reset
    // so the key never gets "stuck" in a pressed state (some cancel paths skip `onEnded`).

    var body: some View {
        content()
            .frame(width: width, height: height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        // Fire once when the press enters this key.
                        guard pressedId != id else { return }
                        pressedId = id
                        onTrigger()

                        // Safety reset in case `onEnded` doesn't fire.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                            if pressedId == id { pressedId = nil }
                        }
                    }
                    .onEnded { _ in
                        if pressedId == id { pressedId = nil }
                    }
            )
    }
}
