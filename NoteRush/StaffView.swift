import SwiftUI
import UIKit

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
