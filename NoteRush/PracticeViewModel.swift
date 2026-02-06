import Foundation
import Combine
import SwiftUI

enum NoteNamingMode: String, CaseIterable, Identifiable {
    case letters
    case solfege

    var id: String {
        return rawValue
    }

    var segmentTitle: String {
        switch self {
        case .letters:
            return "C D E"
        case .solfege:
            return "Do Re Mi"
        }
    }
}

struct TimeSignature: Identifiable, Equatable {
    let numerator: Int
    let denominator: Int

    var id: String {
        return "\(numerator)/\(denominator)"
    }

    var displayName: String {
        return id
    }

    var beatsPerBar: Double {
        return Double(numerator) * 4.0 / Double(denominator)
    }

    static let presets: [TimeSignature] = [
        TimeSignature(numerator: 2, denominator: 4),
        TimeSignature(numerator: 3, denominator: 4),
        TimeSignature(numerator: 4, denominator: 4),
        TimeSignature(numerator: 6, denominator: 8),
    ]

    static let common = TimeSignature(numerator: 4, denominator: 4)
}

enum NoteRhythm: String, CaseIterable, Identifiable {
    case whole
    case half
    case quarter
    case eighth
    case sixteenth

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .whole:
            return "Whole"
        case .half:
            return "Half"
        case .quarter:
            return "Quarter"
        case .eighth:
            return "Eighth"
        case .sixteenth:
            return "16th"
        }
    }

    var displayNameKey: LocalizedStringKey {
        switch self {
        case .whole:
            return "Rhythm.Whole"
        case .half:
            return "Rhythm.Half"
        case .quarter:
            return "Rhythm.Quarter"
        case .eighth:
            return "Rhythm.Eighth"
        case .sixteenth:
            return "Rhythm.Sixteenth"
        }
    }

    /// Duration measured in quarter-note beats.
    var noteIntervalBeats: Double {
        switch self {
        case .whole:
            return 4.0
        case .half:
            return 2.0
        case .quarter:
            return 1.0
        case .eighth:
            return 0.5
        case .sixteenth:
            return 0.25
        }
    }

    static func from(noteIntervalBeats: Double) -> NoteRhythm {
        let options: [(Double, NoteRhythm)] = [
            (4.0, .whole),
            (2.0, .half),
            (1.0, .quarter),
            (0.5, .eighth),
            (0.25, .sixteenth),
        ]

        let closest = options.min(by: { abs($0.0 - noteIntervalBeats) < abs($1.0 - noteIntervalBeats) })
        return closest?.1 ?? .quarter
    }
}

enum NoteDisplayRhythmMode: String, CaseIterable, Identifiable {
    case whole
    case half
    case quarter
    case random

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .whole:
            return "Rhythm.Whole"
        case .half:
            return "Rhythm.Half"
        case .quarter:
            return "Rhythm.Quarter"
        case .random:
            return "Rhythm.Random"
        }
    }

    func resolvedRhythm(seed: String) -> NoteRhythm {
        switch self {
        case .whole:
            return .whole
        case .half:
            return .half
        case .quarter:
            return .quarter
        case .random:
            let options: [NoteRhythm] = [.whole, .half, .quarter]
            var hash = 0
            for scalar in seed.unicodeScalars {
                hash = (hash &* 31) &+ Int(scalar.value)
            }
            let index = abs(hash) % options.count
            return options[index]
        }
    }
}

enum NoteLetter: String, CaseIterable, Hashable {
    case c = "C"
    case d = "D"
    case e = "E"
    case f = "F"
    case g = "G"
    case a = "A"
    case b = "B"

    var diatonicOffset: Int {
        switch self {
        case .c: return 0
        case .d: return 1
        case .e: return 2
        case .f: return 3
        case .g: return 4
        case .a: return 5
        case .b: return 6
        }
    }

    var semitoneOffset: Int {
        switch self {
        case .c: return 0
        case .d: return 2
        case .e: return 4
        case .f: return 5
        case .g: return 7
        case .a: return 9
        case .b: return 11
        }
    }

    var midiNoteNumber: Int {
        // C4..B4
        return 60 + semitoneOffset
    }

    var displayName: String {
        return displayName(for: .letters)
    }

    func displayName(for mode: NoteNamingMode) -> String {
        switch mode {
        case .letters:
            return rawValue
        case .solfege:
            switch self {
            case .c:
                return "Do"
            case .d:
                return "Re"
            case .e:
                return "Mi"
            case .f:
                return "Fa"
            case .g:
                return "Sol"
            case .a:
                return "La"
            case .b:
                return "Ti"
            }
        }
    }
}

enum StaffClef: String, CaseIterable, Identifiable {
    case treble
    case bass

    var id: String { rawValue }
}

enum StaffClefMode: String, CaseIterable, Identifiable {
    case treble
    case bass
    case grand

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .treble:
            return "Clef.Treble"
        case .bass:
            return "Clef.Bass"
        case .grand:
            return "Clef.Grand"
        }
    }

    var clefs: [StaffClef] {
        switch self {
        case .treble:
            return [.treble]
        case .bass:
            return [.bass]
        case .grand:
            return [.treble, .bass]
        }
    }
}

struct PracticeLevel: Identifiable, Equatable {
    let id: Int
    let titleKey: LocalizedStringKey
    let subtitleKey: LocalizedStringKey
    let letters: Set<NoteLetter>
    let indexRange: ClosedRange<Int>
    let rangeTags: [LocalizedStringKey]
    let rhythm: NoteRhythm
    let clefMode: StaffClefMode
    let trebleRange: ClosedRange<Int>?
    let bassRange: ClosedRange<Int>?
}

extension PracticeLevel {
    static let library: [PracticeLevel] = [
        PracticeLevel(
            id: 1,
            titleKey: "PracticeLevel.1.Title",
            subtitleKey: "PracticeLevel.1.Subtitle",
            letters: Set(NoteLetter.allCases),
            indexRange: 2...8,
            rangeTags: ["Clef.Treble"],
            rhythm: .whole,
            clefMode: .treble,
            trebleRange: 2...8,
            bassRange: nil
        ),
        PracticeLevel(
            id: 2,
            titleKey: "PracticeLevel.2.Title",
            subtitleKey: "PracticeLevel.2.Subtitle",
            letters: Set(NoteLetter.allCases),
            indexRange: 0...16,
            rangeTags: ["Clef.Treble", "Tag.Ledger"],
            rhythm: .whole,
            clefMode: .treble,
            trebleRange: 0...16,
            bassRange: nil
        ),
        PracticeLevel(
            id: 3,
            titleKey: "PracticeLevel.3.Title",
            subtitleKey: "PracticeLevel.3.Subtitle",
            letters: Set(NoteLetter.allCases),
            indexRange: 7...13,
            rangeTags: ["Clef.Bass"],
            rhythm: .whole,
            clefMode: .bass,
            trebleRange: nil,
            bassRange: 7...13
        ),
        PracticeLevel(
            id: 4,
            titleKey: "PracticeLevel.4.Title",
            subtitleKey: "PracticeLevel.4.Subtitle",
            letters: Set(NoteLetter.allCases),
            indexRange: 0...16,
            rangeTags: ["Clef.Bass", "Tag.Ledger"],
            rhythm: .half,
            clefMode: .bass,
            trebleRange: nil,
            bassRange: 0...16
        ),
        PracticeLevel(
            id: 5,
            titleKey: "PracticeLevel.5.Title",
            subtitleKey: "PracticeLevel.5.Subtitle",
            letters: Set(NoteLetter.allCases),
            indexRange: 2...8,
            rangeTags: ["Clef.Treble", "Clef.Bass"],
            rhythm: .half,
            clefMode: .grand,
            trebleRange: 2...8,
            bassRange: 7...13
        ),
        PracticeLevel(
            id: 6,
            titleKey: "PracticeLevel.6.Title",
            subtitleKey: "PracticeLevel.6.Subtitle",
            letters: Set(NoteLetter.allCases),
            indexRange: 0...16,
            rangeTags: ["Clef.Treble", "Clef.Bass", "Tag.Ledger"],
            rhythm: .quarter,
            clefMode: .grand,
            trebleRange: 0...16,
            bassRange: 0...16
        ),
    ]
}

struct StaffNote: Equatable, Identifiable {
    let index: Int
    let letter: NoteLetter
    let octave: Int
    let clef: StaffClef
    let isLedgerLine: Bool

    var id: String {
        return "\(clef.rawValue)-\(index)"
    }

    /// MIDI note number for the staff position (C-major, natural notes).
    var midiNoteNumber: Int {
        return (octave + 1) * 12 + letter.semitoneOffset
    }

    /// Diatonic step index for stepwise motion (C0 = 0).
    var diatonicIndex: Int {
        return octave * 7 + letter.diatonicOffset
    }

    static let trebleNotes: [StaffNote] = StaffNote.buildNotes(
        startLetter: .a,
        startOctave: 3,
        clef: .treble
    )

    static let bassNotes: [StaffNote] = StaffNote.buildNotes(
        startLetter: .c,
        startOctave: 2,
        clef: .bass
    )

    static var all: [StaffNote] {
        return trebleNotes
    }

    static func all(for clef: StaffClef) -> [StaffNote] {
        switch clef {
        case .treble:
            return trebleNotes
        case .bass:
            return bassNotes
        }
    }

    static func all(for mode: StaffClefMode) -> [StaffNote] {
        switch mode {
        case .treble:
            return trebleNotes
        case .bass:
            return bassNotes
        case .grand:
            return (trebleNotes + bassNotes).sorted(by: { $0.diatonicIndex < $1.diatonicIndex })
        }
    }

    private static func buildNotes(startLetter: NoteLetter, startOctave: Int, clef: StaffClef) -> [StaffNote] {
        let totalPositions = 17
        var notes: [StaffNote] = []
        var letter = startLetter
        var octave = startOctave

        for index in 0..<totalPositions {
            let isLedgerLine = (index % 2 == 0) && (index < 4 || index > 12)
            notes.append(StaffNote(
                index: index,
                letter: letter,
                octave: octave,
                clef: clef,
                isLedgerLine: isLedgerLine
            ))

            switch letter {
            case .c: letter = .d
            case .d: letter = .e
            case .e: letter = .f
            case .f: letter = .g
            case .g: letter = .a
            case .a: letter = .b
            case .b:
                letter = .c
                octave += 1
            }
        }

        return notes
    }
}

extension StaffNote {
    static func preferred(
        letter: NoteLetter,
        range: ClosedRange<Int> = 2...8,
        clef: StaffClef = .treble
    ) -> StaffNote {
        let notes = all(for: clef)
        let candidates = notes.filter { $0.letter == letter && range.contains($0.index) }
        if candidates.isEmpty {
            return notes.first(where: { $0.letter == letter }) ?? notes[2]
        }

        let center = (range.lowerBound + range.upperBound) / 2
        return candidates.min(by: { abs($0.index - center) < abs($1.index - center) }) ?? candidates[0]
    }

    static func preferred(
        letter: NoteLetter,
        previous: StaffNote?,
        range: ClosedRange<Int>,
        clef: StaffClef = .treble
    ) -> StaffNote {
        let notes = all(for: clef)
        let candidates = notes.filter { $0.letter == letter && range.contains($0.index) }
        guard !candidates.isEmpty else {
            return preferred(letter: letter, range: range, clef: clef)
        }

        if let previous {
            return candidates.min(by: { abs($0.diatonicIndex - previous.diatonicIndex) < abs($1.diatonicIndex - previous.diatonicIndex) })
                ?? candidates[0]
        }

        return preferred(letter: letter, range: range, clef: clef)
    }

    static func exact(letter: NoteLetter, octave: Int, clef: StaffClef) -> StaffNote? {
        let midi = (octave + 1) * 12 + letter.semitoneOffset
        return all(for: clef).first(where: { $0.midiNoteNumber == midi })
    }

    static func exact(letter: NoteLetter, octave: Int, mode: StaffClefMode) -> StaffNote? {
        switch mode {
        case .treble:
            return exact(letter: letter, octave: octave, clef: .treble)
        case .bass:
            return exact(letter: letter, octave: octave, clef: .bass)
        case .grand:
            let midi = (octave + 1) * 12 + letter.semitoneOffset
            let preferredClef: StaffClef = midi >= 64 ? .treble : .bass
            if let exact = exact(letter: letter, octave: octave, clef: preferredClef) {
                return exact
            }
            let fallbackClef: StaffClef = preferredClef == .treble ? .bass : .treble
            return exact(letter: letter, octave: octave, clef: fallbackClef)
        }
    }
}

struct QuestionGenerator {
    private let notes: [StaffNote]
    private(set) var previousNote: StaffNote?

    init(notes: [StaffNote] = StaffNote.all, previousNote: StaffNote? = nil) {
        self.notes = notes.isEmpty ? StaffNote.all : notes
        self.previousNote = previousNote
    }

    mutating func nextNote() -> StaffNote {
        guard notes.count > 1 else {
            let onlyNote = notes.first ?? StaffNote.all[0]
            previousNote = onlyNote
            return onlyNote
        }

        guard let previousNote else {
            let startNote = notes.randomElement() ?? StaffNote.all[0]
            self.previousNote = startNote
            return startNote
        }

        let useStepwise = Double.random(in: 0...1) < 0.7
        var candidates: [StaffNote] = []

        if useStepwise {
            candidates = notes.filter {
                abs($0.diatonicIndex - previousNote.diatonicIndex) <= 2 && $0.id != previousNote.id
            }
        }

        if candidates.isEmpty {
            candidates = notes.filter { $0.id != previousNote.id }
        }

        let nextNote = candidates.randomElement() ?? previousNote
        self.previousNote = nextNote
        return nextNote
    }
}

struct JudgeSystem {
    func isCorrect(note: StaffNote, answer: NoteLetter) -> Bool {
        return note.letter == answer
    }
}

final class PracticeViewModel: ObservableObject {
    private let baseTime: Double = 2.0
    private let bonusTime: Double = 0.2
    private let maxTime: Double = 3.0
    private let tickInterval: Double = 0.05

    @Published var currentNote: StaffNote
    @Published var timeRemaining: Double
    @Published var timeLimit: Double
    @Published var combo: Int
    @Published var totalAnswered: Int
    @Published var totalCorrect: Int
    @Published var flashCorrect: Bool
    @Published var shakeTrigger: Int

    private var generator = QuestionGenerator()
    private let judge = JudgeSystem()
    private var timer: Timer?
    private var isLocked = false

    init() {
        let note = generator.nextNote()
        currentNote = note
        timeLimit = baseTime
        timeRemaining = baseTime
        combo = 0
        totalAnswered = 0
        totalCorrect = 0
        flashCorrect = false
        shakeTrigger = 0
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func select(letter: NoteLetter) {
        guard !isLocked else { return }
        let isCorrect = judge.isCorrect(note: currentNote, answer: letter)
        handleAnswer(isCorrect: isCorrect)
    }

    var accuracy: Double {
        guard totalAnswered > 0 else { return 0 }
        return Double(totalCorrect) / Double(totalAnswered)
    }

    private func tick() {
        guard !isLocked else { return }
        timeRemaining = max(0, timeRemaining - tickInterval)

        if timeRemaining <= 0 {
            handleAnswer(isCorrect: false)
        }
    }

    private func handleAnswer(isCorrect: Bool) {
        isLocked = true
        totalAnswered += 1

        if isCorrect {
            totalCorrect += 1
            combo += 1
            triggerCorrectFeedback()
        } else {
            combo = 0
            triggerIncorrectFeedback()
        }

        let delay = isCorrect ? 0.2 : 0.3
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.nextQuestion()
        }
    }

    private func nextQuestion() {
        currentNote = generator.nextNote()
        timeLimit = min(baseTime + Double(combo) * bonusTime, maxTime)
        timeRemaining = timeLimit
        isLocked = false
    }

    private func triggerCorrectFeedback() {
        flashCorrect = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.flashCorrect = false
        }
    }

    private func triggerIncorrectFeedback() {
        shakeTrigger += 1
    }
}
