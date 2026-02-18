import SwiftUI
import UIKit
import Combine

struct StaffLayoutSlot {
    let metrics: StaffMetrics
    let yOffset: CGFloat
}

struct ClefIconView: View {
    let clef: StaffClef
    let metrics: StaffMetrics
    let yOffset: CGFloat

    var body: some View {
        let assetName = clef == .treble ? "high" : "low"
        let iconSize = metrics.lineSpacing * 7.8
        let minX = iconSize * 0.45
        let xPosition = max(minX, metrics.leftMargin - metrics.lineSpacing * 1.2)
        let yPosition = clef == .treble
            ? (metrics.y(for: metrics.topStaffLineIndex) + metrics.y(for: metrics.bottomStaffLineIndex)) / 2
            : (metrics.y(for: metrics.topStaffLineIndex) + metrics.y(for: metrics.bottomStaffLineIndex)) / 2

        return Group {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .opacity(CuteTheme.clefOpacity)
        }
        .position(x: xPosition, y: yPosition + yOffset)
    }
}

struct StaffLayout {
    let mode: StaffClefMode
    let single: StaffLayoutSlot
    let treble: StaffLayoutSlot?
    let bass: StaffLayoutSlot?

    init(size: CGSize, mode: StaffClefMode) {
        self.mode = mode

        switch mode {
        case .grand:
            let gap = size.height * 0.12
            let staffHeight = max(1, (size.height - gap) / 2)
            let trebleMetrics = StaffMetrics(size: CGSize(width: size.width, height: staffHeight))
            let bassMetrics = StaffMetrics(size: CGSize(width: size.width, height: staffHeight))

            let trebleSlot = StaffLayoutSlot(metrics: trebleMetrics, yOffset: 0)
            let bassSlot = StaffLayoutSlot(metrics: bassMetrics, yOffset: staffHeight + gap)

            self.treble = trebleSlot
            self.bass = bassSlot
            self.single = trebleSlot
        case .treble, .bass:
            let metrics = StaffMetrics(size: size)
            let slot = StaffLayoutSlot(metrics: metrics, yOffset: 0)
            self.treble = nil
            self.bass = nil
            self.single = slot
        }
    }

    func slot(for clef: StaffClef) -> StaffLayoutSlot {
        switch mode {
        case .grand:
            if clef == .bass {
                return bass ?? single
            }
            return treble ?? single
        case .treble, .bass:
            return single
        }
    }
}

struct StaffView: View {
    let note: StaffNote
    let flashCorrect: Bool
    let flashIncorrect: Bool
    let shakeTrigger: Int
    let rhythm: NoteRhythm
    let clefMode: StaffClefMode
    let noteColor: Color

    init(
        note: StaffNote,
        flashCorrect: Bool,
        flashIncorrect: Bool,
        shakeTrigger: Int,
        rhythm: NoteRhythm = .quarter,
        clefMode: StaffClefMode = .treble,
        noteColor: Color = .black
    ) {
        self.note = note
        self.flashCorrect = flashCorrect
        self.flashIncorrect = flashIncorrect
        self.shakeTrigger = shakeTrigger
        self.rhythm = rhythm
        self.clefMode = clefMode
        self.noteColor = noteColor
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = StaffLayout(size: proxy.size, mode: clefMode)
            let noteSlot = layout.slot(for: note.clef)

            ZStack {
                if clefMode == .grand {
                    if let treble = layout.treble {
                        ClefIconView(clef: .treble, metrics: treble.metrics, yOffset: treble.yOffset)
                            .zIndex(-1)
                    }
                    if let bass = layout.bass {
                        ClefIconView(clef: .bass, metrics: bass.metrics, yOffset: bass.yOffset)
                            .zIndex(-1)
                    }
                } else if clefMode == .bass {
                    ClefIconView(clef: .bass, metrics: layout.single.metrics, yOffset: 0)
                        .zIndex(-1)
                } else {
                    ClefIconView(clef: .treble, metrics: layout.single.metrics, yOffset: 0)
                        .zIndex(-1)
                }

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
                NoteGlyphView(
                    note: note,
                    metrics: noteSlot.metrics,
                    xPosition: noteSlot.metrics.noteX,
                    color: noteColor,
                    rhythm: rhythm,
                    flashCorrect: flashCorrect,
                    flashIncorrect: flashIncorrect,
                    yOffset: noteSlot.yOffset
                )
                .zIndex(2)
                .modifier(ShakeEffect(animatableData: CGFloat(shakeTrigger)))
                .animation(.linear(duration: 0.4), value: shakeTrigger)

                if let pairedNote = pairedNote(for: note) {
                    let pairedSlot = layout.slot(for: pairedNote.clef)
                    NoteGlyphView(
                        note: pairedNote,
                        metrics: pairedSlot.metrics,
                        xPosition: pairedSlot.metrics.noteX,
                        color: noteColor,
                        rhythm: rhythm,
                        flashCorrect: flashCorrect,
                        flashIncorrect: flashIncorrect,
                        yOffset: pairedSlot.yOffset,
                        showNoteName: false,
                        namingMode: .letters
                    )
                    .zIndex(2)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Note \(note.letter.displayName)")
    }

    private func pairedNote(for note: StaffNote) -> StaffNote? {
        guard clefMode == .grand else { return nil }
        let otherClef: StaffClef = note.clef == .treble ? .bass : .treble
        return StaffNote.all(for: otherClef).first { $0.midiNoteNumber == note.midiNoteNumber }
    }
}

struct StaffMetrics {
    let size: CGSize
    let pixelScale: CGFloat

    let lineSpacing: CGFloat
    let stepSpacing: CGFloat

    // Single staff: 5 staff lines + 2 ledger lines above/below.
    // Index represents diatonic steps between lines/spaces.
    // Range (0..16) maps to the clef's configured pitch span.
    let lowestIndex: Int = 0
    let highestIndex: Int = 16

    // Staff lines (E4, G4, B4, D5, F5)
    let staffLineIndices: [Int] = [4, 6, 8, 10, 12]

    let leftMargin: CGFloat
    let rightMargin: CGFloat

    var bottomStaffLineIndex: Int { staffLineIndices.min() ?? 0 }
    var topStaffLineIndex: Int { staffLineIndices.max() ?? 0 }

    init(size: CGSize) {
        self.size = size
        self.pixelScale = UIScreen.main.scale

        let totalSteps = CGFloat(highestIndex - lowestIndex)
        let usableHeight = size.height * 0.8
        let rawStepSpacing = usableHeight / totalSteps
        let stepSpacing = StaffMetrics.roundToPixel(rawStepSpacing, scale: pixelScale)

        self.stepSpacing = stepSpacing
        self.lineSpacing = stepSpacing * 2
        self.leftMargin = StaffMetrics.roundToPixel(size.width * 0.08, scale: pixelScale)
        self.rightMargin = StaffMetrics.roundToPixel(size.width * 0.92, scale: pixelScale)
    }

    var strokeWidth: CGFloat {
        let raw = max(1, lineSpacing * 0.06)
        return StaffMetrics.roundToPixel(raw, scale: pixelScale)
    }

    func y(for index: Int) -> CGFloat {
        let totalSteps = CGFloat(highestIndex - lowestIndex)
        let centerY = StaffMetrics.roundToPixel(size.height / 2, scale: pixelScale)
        let lowestY = centerY + (totalSteps * stepSpacing) / 2
        let yValue = lowestY - CGFloat(index - lowestIndex) * stepSpacing
        return StaffMetrics.roundToPixel(yValue, scale: pixelScale)
    }

    var noteX: CGFloat {
        return StaffMetrics.roundToPixel(size.width * 0.5, scale: pixelScale)
    }

    /// Returns which ledger *line* indices should be drawn for a note at `noteIndex`.
    /// This includes drawing the intermediate ledger line when the note is on the 2nd ledger line
    /// (or in the space between the 1st and 2nd ledger lines).
    func ledgerLineIndices(for noteIndex: Int) -> [Int] {
        var indices: [Int] = []

        // Below staff: ledger lines start at (bottomStaffLineIndex - 2).
        if noteIndex <= bottomStaffLineIndex - 1 {
            if noteIndex == bottomStaffLineIndex - 1 {
                return indices
            }
            let firstLedger = bottomStaffLineIndex - 2
            let minNeeded = noteIndex % 2 == 0 ? noteIndex : noteIndex + 1
            var i = firstLedger
            while i >= lowestIndex && i >= minNeeded {
                indices.append(i)
                i -= 2
            }
        }

        // Above staff: ledger lines start at (topStaffLineIndex + 2).
        if noteIndex >= topStaffLineIndex + 1 {
            if noteIndex == topStaffLineIndex + 1 {
                return indices
            }
            let firstLedger = topStaffLineIndex + 2
            let maxNeeded = noteIndex % 2 == 0 ? noteIndex : noteIndex - 1
            var i = firstLedger
            while i <= highestIndex && i <= maxNeeded {
                indices.append(i)
                i += 2
            }
        }

        return indices
    }

    static func roundToPixel(_ value: CGFloat, scale: CGFloat) -> CGFloat {
        guard scale > 0 else { return value }
        return (value * scale).rounded() / scale
    }
}

struct StaffLinesView: View {
    let metrics: StaffMetrics

    var body: some View {
        Path { path in
            for index in metrics.staffLineIndices {
                let y = metrics.y(for: index)
                path.move(to: CGPoint(x: metrics.leftMargin, y: y))
                path.addLine(to: CGPoint(x: metrics.rightMargin, y: y))
            }
        }
        .stroke(CuteTheme.staffLineColor, lineWidth: metrics.strokeWidth)
    }
}

// MARK: - Missing types recreated after local cleanup

// NoteNamingMode / NoteLetter / StaffClef / StaffClefMode / NoteRhythm / NoteDisplayRhythmMode / PracticeLevel / StaffNote
// already exist in PracticeViewModel.swift.

enum Judgement {
    case perfect
    case miss
}

struct ScrollConfig {
    /// Where the dashed judgement line is placed horizontally (0 = left, 1 = right).
    /// Jason request: keep it centered.
    var judgementXRatio: Double = 0.50
    var leadTime: Double = 2.0
}

struct SongNoteEvent: Identifiable {
    let id: UUID
    let time: TimeInterval
    let note: StaffNote
    let isTarget: Bool
    var judgement: Judgement?

    init(id: UUID = UUID(), time: TimeInterval, note: StaffNote, isTarget: Bool = true, judgement: Judgement? = nil) {
        self.id = id
        self.time = time
        self.note = note
        self.isTarget = isTarget
        self.judgement = judgement
    }
}




// MARK: - Song / language models (recreated after local cleanup)

extension NoteLetter {
    /// Map an arbitrary MIDI note number (chromatic) to its natural letter (C D E F G A B).
    /// This intentionally drops accidentals.
    static func fromSemitone(_ midi: Int) -> NoteLetter? {
        let pc = ((midi % 12) + 12) % 12
        switch pc {
        case 0, 1: return .c
        case 2, 3: return .d
        case 4: return .e
        case 5, 6: return .f
        case 7, 8: return .g
        case 9, 10: return .a
        case 11: return .b
        default: return nil
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case en
    case zhHans

    var id: String { rawValue }

    var flag: String {
        switch self {
        case .system: return "🌐"
        case .en: return "🇺🇸"
        case .zhHans: return "🇨🇳"
        }
    }

    var nativeName: String {
        switch self {
        case .system: return "System"
        case .en: return "English"
        case .zhHans: return "简体中文"
        }
    }

    var locale: Locale {
        switch self {
        case .system: return .current
        case .en: return Locale(identifier: "en")
        case .zhHans: return Locale(identifier: "zh-Hans")
        }
    }
}

struct MelodyNote: Identifiable, Equatable {
    let id = UUID()
    let letter: NoteLetter
    let beats: Double
}

struct Song: Identifiable {
    let id = UUID()
    let title: String
    var bpm: Double
    var timeSignature: TimeSignature
    var rhythm: NoteRhythm
    var duration: TimeInterval
    var clefMode: StaffClefMode
    var notes: [StaffNote]

    var rhythmLabel: String { rhythm.displayName }

    static func generate(
        title: String,
        bpm: Double,
        duration: TimeInterval,
        timeSignature: TimeSignature,
        rhythm: NoteRhythm,
        spawnLetters: Set<NoteLetter>,
        targetLetters: Set<NoteLetter>,
        clefMode: StaffClefMode
    ) -> Song {
        let pool: [StaffNote]
        switch clefMode {
        case .treble:
            pool = StaffNote.all(for: StaffClef.treble)
        case .bass:
            pool = StaffNote.all(for: StaffClef.bass)
        case .grand:
            // For now, just use treble range for generation.
            pool = StaffNote.all(for: StaffClef.treble)
        }

        let candidates = pool.filter { spawnLetters.contains($0.letter) }
        let noteCount = max(8, Int(duration * (bpm / 60.0) / max(0.25, rhythm.noteIntervalBeats)))
        var out: [StaffNote] = []
        out.reserveCapacity(noteCount)
        for i in 0..<noteCount {
            out.append(candidates.isEmpty ? pool[i % pool.count] : candidates[Int.random(in: 0..<candidates.count)])
        }

        return Song(title: title, bpm: bpm, timeSignature: timeSignature, rhythm: rhythm, duration: duration, clefMode: clefMode, notes: out)
    }

    static func generateFixed(
        title: String,
        bpm: Double,
        timeSignature: TimeSignature,
        melody: [MelodyNote],
        targetLetters: Set<NoteLetter>,
        clefMode: StaffClefMode
    ) -> Song {
        let pool: [StaffNote] = (clefMode == .bass) ? StaffNote.all(for: StaffClef.bass) : StaffNote.all(for: StaffClef.treble)
        let notes: [StaffNote] = melody.compactMap { m in pool.first(where: { $0.letter == m.letter }) ?? pool.first }
        let duration = max(8, Double(melody.count))
        return Song(title: title, bpm: bpm, timeSignature: timeSignature, rhythm: .quarter, duration: duration, clefMode: clefMode, notes: notes)
    }

    static func generateEndless(
        title: String,
        bpm: Double,
        timeSignature: TimeSignature,
        rhythm: NoteRhythm,
        spawnLetters: Set<NoteLetter>,
        targetLetters: Set<NoteLetter>,
        allowedIndices: ClosedRange<Int>? = nil,
        clefMode: StaffClefMode,
        allowedNotes: [StaffNote]? = nil
    ) -> Song {
        let pool: [StaffNote] = allowedNotes ?? ((clefMode == .bass) ? StaffNote.all(for: StaffClef.bass) : StaffNote.all(for: StaffClef.treble))
        let indexedPool = allowedIndices.map { r in pool.filter { r.contains($0.index) } } ?? pool
        let candidates = indexedPool.filter { spawnLetters.contains($0.letter) }
        let notes = (0..<64).map { i in
            candidates.isEmpty ? pool[i % pool.count] : candidates[Int.random(in: 0..<candidates.count)]
        }
        return Song(title: title, bpm: bpm, timeSignature: timeSignature, rhythm: rhythm, duration: 9999, clefMode: clefMode, notes: notes)
    }
}

struct SongTemplate: Identifiable {
    let id: UUID
    let title: String
    let level: Int
    let allowedLetters: Set<NoteLetter>

    // For RootView.buildSong(...)
    let duration: TimeInterval
    let rhythm: NoteRhythm
    let melody: [MelodyNote]?

    static let library: [SongTemplate] = [
        SongTemplate(
            id: UUID(),
            title: "Song 1",
            level: 1,
            allowedLetters: [.c, .d, .e],
            duration: 18,
            rhythm: .quarter,
            melody: nil
        ),
        SongTemplate(
            id: UUID(),
            title: "Song 2",
            level: 1,
            allowedLetters: [.c, .d, .e, .f, .g],
            duration: 22,
            rhythm: .quarter,
            melody: nil
        )
    ]
}

final class SongViewModel: ObservableObject {
    @Published private(set) var song: Song
    @Published private(set) var bpm: Double
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var isPaused: Bool = false
    @Published private(set) var isFinished: Bool = false

    @Published private(set) var lastJudgement: Judgement?
    @Published private(set) var lastJudgementTime: TimeInterval = 0
    @Published private(set) var lastJudgementLetter: NoteLetter?

    @Published private(set) var events: [SongNoteEvent] = []

    var scrollConfig: ScrollConfig { ScrollConfig() }
    /// Scrolling speed multiplier.
    /// Requirement: changing BPM should both speed up the scroll AND make notes closer together.
    /// If we scaled linearly with BPM, spacing would cancel out (faster but same distance).
    /// Use a sub-linear curve so higher BPM still yields denser note spacing.
    var scrollSpeedMultiplier: Double {
        let base: Double = 80
        let ratio = max(0.5, min(3.0, bpm / base))
        return pow(ratio, 0.7)
    }
    var noteScale: Double { 1.0 }

    private var timer: Timer?
    private var currentIndex: Int = 0

    init(song: Song) {
        self.song = song
        self.bpm = song.bpm
        rebuildEvents()
        soundAnchorNote = currentTargetNote
    }

    var progress: Double {
        guard !song.notes.isEmpty else { return 0 }
        return Double(currentIndex) / Double(song.notes.count)
    }

    var accuracy: Double {
        let judged = events.compactMap { $0.judgement }
        guard !judged.isEmpty else { return 0 }
        let correct = judged.filter { $0 == .perfect }.count
        return Double(correct) / Double(judged.count)
    }

    var currentTargetNote: StaffNote? {
        guard currentIndex < song.notes.count else { return nil }
        return song.notes[currentIndex]
    }

    /// Locks the keyboard sound octave while the current note is being judged.
    /// Updated only AFTER the judgement window fully ends.
    @Published private(set) var soundAnchorNote: StaffNote?

    private var pendingSoundAnchorNote: StaffNote?
    private var soundAnchorSwitchTime: TimeInterval? // when to apply pending anchor

    func start() {
        stop()
        isPaused = false
        isFinished = false
        timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func resume() { start() }

    func togglePause() {
        isPaused.toggle()
    }

    func restart(withBpm newBpm: Double) {
        bpm = newBpm
        song.bpm = newBpm
        currentTime = 0
        currentIndex = 0
        lastJudgement = nil
        rebuildEvents()
        soundAnchorNote = currentTargetNote
        start()
    }

    func restart() {
        restart(withBpm: bpm)
    }


    func endSession() {
        stop()
        isFinished = true
    }

    func select(letter: NoteLetter) {
        guard !isPaused, !isFinished else { return }
        guard currentIndex < events.count else { return }

        // Judge against the note that is currently at the dashed line.
        // event.time == currentTime when the note is exactly on the line.
        let hitWindow: TimeInterval = 0.42
        let anchorDelay = hitWindow

        // Prefer the earliest unjudged note.
        let idx = currentIndex
        let targetEvent = events[idx]
        let dt = targetEvent.time - currentTime

        // If the user taps too early/late, ignore (so we don't judge the wrong note).
        guard abs(dt) <= hitWindow else { return }

        let correct = (letter == targetEvent.note.letter)
        let judgement: Judgement = correct ? .perfect : .miss

        lastJudgement = judgement
        lastJudgementLetter = targetEvent.note.letter
        lastJudgementTime = currentTime

        events[idx].judgement = judgement

        // Advance regardless (the note at the line has been judged).
        currentIndex += 1

        // Do NOT change octave immediately on correct/miss; wait until the judgement window ends.
        pendingSoundAnchorNote = currentTargetNote
        soundAnchorSwitchTime = currentTime + anchorDelay

        if currentIndex >= events.count {
            endSession()
        }
    }

    private func tick() {
        guard !isPaused, !isFinished else { return }
        currentTime += 0.02

        // Apply pending sound anchor switch only after the judgement window ends.
        if let t = soundAnchorSwitchTime, currentTime >= t {
            soundAnchorNote = pendingSoundAnchorNote
            pendingSoundAnchorNote = nil
            soundAnchorSwitchTime = nil
        }

        // Auto-miss notes that have passed the dashed line without being judged.
        let missWindow: TimeInterval = 0.42
        while currentIndex < events.count {
            let e = events[currentIndex]
            if e.judgement != nil {
                currentIndex += 1
                continue
            }
            if currentTime > e.time + missWindow {
                events[currentIndex].judgement = .miss
                lastJudgement = .miss
                lastJudgementLetter = e.note.letter
                lastJudgementTime = currentTime
                currentIndex += 1

                pendingSoundAnchorNote = currentTargetNote
                soundAnchorSwitchTime = currentTime + missWindow
                continue
            }
            break
        }

        if currentIndex >= events.count {
            endSession()
        }
    }

    private func rebuildEvents() {
        let secondsPerBeat = 60.0 / max(10, bpm)
        let noteInterval = secondsPerBeat * song.rhythm.noteIntervalBeats
        events = song.notes.enumerated().map { idx, note in
            SongNoteEvent(time: TimeInterval(idx) * noteInterval, note: note, isTarget: true)
        }
    }
}

// MARK: - Utility effects / placeholders

/// Minimal shake effect used by StaffView.
struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = sin(animatableData * .pi * 2) * 6
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

/// Minimal feedback manager placeholder.
/// (Previously played piano-like tap audio; reintroduce later.)
enum InputFeedbackManager {
    /// Play a kid-friendly piano sound for the tapped key.
    /// If `referenceNote` is available (current target note on the staff), we choose the octave
    /// closest to that note so the sound matches what the user sees (the note left of the dashed line).
    static func noteButtonTapped(letter: NoteLetter, referenceNote: StaffNote?) {
        guard let referenceNote else {
            // Fallback: C4..B4
            PianoSoundEngine.shared.play(midi: letter.midiNoteNumber)
            return
        }

        let refMidi = referenceNote.midiNoteNumber

        // Start from the same octave as the reference note.
        var midi = (referenceNote.octave + 1) * 12 + letter.semitoneOffset

        // Adjust by octaves to the closest pitch to the reference.
        while midi - refMidi > 6 { midi -= 12 }
        while refMidi - midi > 6 { midi += 12 }

        PianoSoundEngine.shared.play(midi: midi)
    }
}


/// Minimal microphone detector placeholder.
/// (Previously performed pitch detection; reintroduce later.)
final class MicrophonePitchDetector: ObservableObject {
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var lastDetectedLetter: NoteLetter?

    func start() { isRunning = true }
    func stop() { isRunning = false }
}

// MARK: - Piano keyboard style input (cute, kid-friendly)

/// A piano-like keyboard for button input mode.
///
/// Note: Practice/Song modes currently judge only on `NoteLetter` (natural notes).
/// Black keys still produce sound and are tappable; for now we map them to the nearest-lower white key.
/// If we later extend the training content to chromatic answers, change `onSelect` to a chromatic type.
struct PianoPressStyle: ButtonStyle {
    let isBlack: Bool

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed

        // Important: DO NOT move/scale the view when pressed.
        // On iPhone, the keyboard sits flush to the bottom safe area; any movement gets clipped and
        // looks like the key "shrinks". We simulate "pressed down" using inner shading only.
        return configuration.label
            .transaction { $0.animation = nil }
            .overlay(
                // Outer bottom edge line (always)
                Rectangle()
                    .fill(Color.black.opacity(0.22))
                    .frame(height: 1)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            )
            .overlay(
                // Top highlight when NOT pressed
                Rectangle()
                    .fill(Color.white.opacity(isBlack ? 0.10 : 0.22))
                    .frame(height: isBlack ? 1 : 2)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .opacity(pressed ? 0.0 : 1.0)
            )
            .overlay(
                // Inner "inset" shading when pressed (no shadows, no movement)
                VStack(spacing: 0) {
                    // darker top (gives depth)
                    Rectangle().fill(Color.black.opacity(pressed ? (isBlack ? 0.28 : 0.10) : 0))
                        .frame(height: isBlack ? 8 : 10)

                    // subtle overall darkening
                    Rectangle().fill(Color.black.opacity(pressed ? (isBlack ? 0.14 : 0.06) : 0))

                    // slightly brighter bottom edge (like contact)
                    Rectangle().fill(Color.white.opacity(pressed ? (isBlack ? 0.05 : 0.10) : 0))
                        .frame(height: isBlack ? 2 : 3)
                }
                .allowsHitTesting(false)
            )
            // Keep a constant shadow so the key doesn't look like it changes height.
            .shadow(color: Color.black.opacity(isBlack ? 0.30 : 0.18), radius: 4, x: 0, y: 3)
    }
}

private struct PianoTouchKey: View {
    let id: String
    let isBlack: Bool
    let width: CGFloat
    let height: CGFloat
    let content: AnyView
    @Binding var pressedId: String?
    let onTrigger: () -> Void

    var isPressed: Bool { pressedId == id }

    var body: some View {
        content
            .frame(width: width, height: height)
            .contentShape(Rectangle())
            // Pressed appearance: inner shading only (no movement) to avoid "shorter key" clipping.
            .overlay(
                VStack(spacing: 0) {
                    Rectangle().fill(Color.black.opacity(isPressed ? (isBlack ? 0.28 : 0.10) : 0))
                        .frame(height: isBlack ? 8 : 10)
                    Rectangle().fill(Color.black.opacity(isPressed ? (isBlack ? 0.14 : 0.06) : 0))
                    Rectangle().fill(Color.white.opacity(isPressed ? (isBlack ? 0.05 : 0.10) : 0))
                        .frame(height: isBlack ? 2 : 3)
                }
                .allowsHitTesting(false)
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if pressedId != id {
                            pressedId = id
                            onTrigger()
                        }
                    }
                    .onEnded { _ in
                        if pressedId == id { pressedId = nil }
                    }
            )
            .transaction { $0.animation = nil }
    }
}

struct PianoKeyboardInputView: View {
    let namingMode: NoteNamingMode
    let useColoredKeys: Bool
    let onSelect: (NoteLetter) -> Void

    @State private var pressedId: String? = nil

    // One octave C..B (C4..B4)
    private let whiteLetters: [NoteLetter] = [.c, .d, .e, .f, .g, .a, .b]

    private struct BlackKey {
        let afterWhiteIndex: Int // black key sits after this white key
        let labelLetters: String
        let labelSolfege: String
        let midi: Int
        let mapsTo: NoteLetter
    }

    // C#, D#, F#, G#, A#
    private var blackKeys: [BlackKey] {
        [
            BlackKey(afterWhiteIndex: 0, labelLetters: "C#", labelSolfege: "Do#", midi: 61, mapsTo: .c),
            BlackKey(afterWhiteIndex: 1, labelLetters: "D#", labelSolfege: "Re#", midi: 63, mapsTo: .d),
            BlackKey(afterWhiteIndex: 3, labelLetters: "F#", labelSolfege: "Fa#", midi: 66, mapsTo: .f),
            BlackKey(afterWhiteIndex: 4, labelLetters: "G#", labelSolfege: "Sol#", midi: 68, mapsTo: .g),
            BlackKey(afterWhiteIndex: 5, labelLetters: "A#", labelSolfege: "La#", midi: 70, mapsTo: .a),
        ]
    }

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            // No outer "card" background; let the keys fill the entire available area.
            let innerPad: CGFloat = 0

            let contentW = max(0, w - innerPad * 2)
            let contentH = max(0, h - innerPad * 2)

            let gap: CGFloat = 2
            let whiteCount = CGFloat(whiteLetters.count)
            let whiteW = (contentW - gap * (whiteCount - 1)) / whiteCount
            let blackW = whiteW * 0.62
            let blackH = contentH * 0.58

            ZStack(alignment: .topLeading) {
                // No background behind the keys (transparent)

                // Keys
                ZStack(alignment: .topLeading) {
                    HStack(spacing: gap) {
                    ForEach(whiteLetters.indices, id: \ .self) { i in
                        let letter = whiteLetters[i]
                        PianoTouchKey(
                            id: "w_\(letter.rawValue)",
                            isBlack: false,
                            width: whiteW,
                            height: contentH,
                            content: AnyView(
                                ZStack {
                                    // White key surface (separate keys; background shows between them)
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.white)

                                    // (no solid separators; use gaps + border)

                                    // Key border so white keys remain visually distinct
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.black.opacity(0.12), lineWidth: 1)

                                    Text(letter.displayName(for: namingMode))
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundColor(CuteTheme.textPrimary)
                                        .padding(.bottom, 32)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                                        .background(
                                            Color.white.opacity(0.0001)
                                        )
                                }
                            ),
                            pressedId: $pressedId,
                            onTrigger: {
                                onSelect(letter)
                            }
                        )
                    }
                }

                ForEach(blackKeys.indices, id: \ .self) { idx in
                    let bk = blackKeys[idx]
                    let boundaryX = (CGFloat(bk.afterWhiteIndex) + 1) * (whiteW + gap) - gap / 2
                    let x = boundaryX - blackW / 2
                    PianoTouchKey(
                        id: "b_\(bk.labelLetters)",
                        isBlack: true,
                        width: blackW,
                        height: blackH,
                        content: AnyView(
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.black.opacity(0.95))
                                    .shadow(color: Color.black.opacity(0.25), radius: 5, x: 0, y: 3)

                                Text(namingMode == .letters ? bk.labelLetters : bk.labelSolfege)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(Color.white)
                                    .padding(.bottom, 20)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            }
                        ),
                        pressedId: $pressedId,
                        onTrigger: {
                            onSelect(bk.mapsTo)
                        }
                    )
                    // Use offset (top-left anchored) to avoid position hit-test quirks.
                    .offset(x: innerPad + x, y: innerPad)
                    .zIndex(10)
                }
                .offset(x: innerPad, y: innerPad)
                }
            }
        }
        .frame(minHeight: 180)
        .frame(maxWidth: .infinity)
    }
}
