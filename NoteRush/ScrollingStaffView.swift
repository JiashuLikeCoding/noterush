import SwiftUI

struct ScrollingStaffView: View {
    let events: [SongNoteEvent]
    let currentTime: TimeInterval
    let scrollConfig: ScrollConfig
    let noteScale: CGFloat
    let scrollSpeedMultiplier: Double
    let lastJudgement: Judgement?
    let lastJudgementTime: TimeInterval
    let lastJudgementLetter: NoteLetter?
    let clefMode: StaffClefMode
    let showNoteName: Bool
    let showJudgementNoteName: Bool
    let useColoredNotes: Bool
    let displayRhythmMode: NoteDisplayRhythmMode
    let namingMode: NoteNamingMode

    var body: some View {
        GeometryReader { proxy in
            let layout = StaffLayout(size: proxy.size, mode: clefMode)
            let referenceMetrics = layout.single.metrics
            let rawJudgementX = proxy.size.width * CGFloat(scrollConfig.judgementXRatio)
            let judgementX = StaffMetrics.roundToPixel(rawJudgementX, scale: referenceMetrics.pixelScale)
            let leftSpan = judgementX - referenceMetrics.leftMargin
            let pixelsPerSecond = leftSpan / CGFloat(scrollConfig.leadTime)
            let speedScale = pixelsPerSecond * CGFloat(scrollSpeedMultiplier)
            let leftLimit = referenceMetrics.leftMargin - 24
            let rightLimit = referenceMetrics.rightMargin + 24
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
                    ClefIconView(clef: .bass, metrics: referenceMetrics, yOffset: 0)
                        .zIndex(-1)
                } else {
                    ClefIconView(clef: .treble, metrics: referenceMetrics, yOffset: 0)
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
                    StaffLinesView(metrics: referenceMetrics)
                        .zIndex(0)
                }

                Path { path in
                    let topY: CGFloat
                    let bottomY: CGFloat
                    if clefMode == .grand, let treble = layout.treble, let bass = layout.bass {
                        topY = treble.metrics.y(for: treble.metrics.highestIndex) + treble.yOffset
                        bottomY = bass.metrics.y(for: bass.metrics.lowestIndex) + bass.yOffset
                    } else {
                        topY = referenceMetrics.y(for: referenceMetrics.highestIndex)
                        bottomY = referenceMetrics.y(for: referenceMetrics.lowestIndex)
                    }
                    path.move(to: CGPoint(x: judgementX, y: bottomY))
                    path.addLine(to: CGPoint(x: judgementX, y: topY))
                }
                .stroke(
                    Color.black.opacity(0.6),
                    style: StrokeStyle(lineWidth: referenceMetrics.strokeWidth, dash: [6, 6])
                )
                .zIndex(1)

                ForEach(events) { event in
                    let timeOffset = event.time - currentTime
                    let rawXPosition = judgementX - CGFloat(timeOffset) * speedScale
                    let xPosition = StaffMetrics.roundToPixel(rawXPosition, scale: referenceMetrics.pixelScale)

                    if xPosition >= leftLimit && xPosition <= rightLimit {
                        let baseColor = baseNoteColor(for: event.note, isTarget: event.isTarget)
                        let displayColor = noteColor(for: event.judgement, baseColor: baseColor)
                        let noteSlot = layout.slot(for: event.note.clef)

                        let displayRhythm = displayRhythmMode.resolvedRhythm(seed: event.id.uuidString)
                        MovingNoteView(
                            note: event.note,
                            metrics: noteSlot.metrics,
                            xPosition: xPosition,
                            scale: noteScale,
                            noteColor: displayColor,
                            rhythm: displayRhythm,
                            judgement: event.judgement,
                            yOffset: noteSlot.yOffset,
                            showNoteName: showNoteName,
                            namingMode: namingMode
                        )
                        .zIndex(2)

                        if let pairedNote = pairedNote(for: event.note) {
                            let pairedSlot = layout.slot(for: pairedNote.clef)
                            NoteGlyphView(
                                note: pairedNote,
                                metrics: pairedSlot.metrics,
                                xPosition: xPosition,
                                color: displayColor,
                                rhythm: displayRhythm,
                                scale: noteScale,
                                yOffset: pairedSlot.yOffset,
                                showNoteName: showNoteName,
                                namingMode: namingMode
                            )
                            .zIndex(2)
                        }
                    }
                }

            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Scrolling staff")
    }

    private func noteColor(for judgement: Judgement?, baseColor: Color) -> Color {
        // Jason request: if correct, make the entire note green.
        guard let judgement else { return baseColor }
        switch judgement {
        case .perfect:
            return CuteTheme.judgementCorrect
        case .miss:
            return CuteTheme.judgementWrong
        }
    }

    private func baseNoteColor(for note: StaffNote, isTarget: Bool) -> Color {
        let base = useColoredNotes ? CuteTheme.noteColor(for: note.letter) : Color.black
        return base
    }

    private func pairedNote(for note: StaffNote) -> StaffNote? {
        guard clefMode == .grand else { return nil }
        let otherClef: StaffClef = note.clef == .treble ? .bass : .treble
        return StaffNote.all(for: otherClef).first { $0.midiNoteNumber == note.midiNoteNumber }
    }
}

struct MovingNoteView: View {
    let note: StaffNote
    let metrics: StaffMetrics
    let xPosition: CGFloat
    let scale: CGFloat
    let noteColor: Color
    let rhythm: NoteRhythm
    let judgement: Judgement?
    let yOffset: CGFloat
    let showNoteName: Bool
    let namingMode: NoteNamingMode

    var body: some View {
        NoteGlyphView(
            note: note,
            metrics: metrics,
            xPosition: xPosition,
            color: noteColor,
            rhythm: rhythm,
            scale: scale,
            judgement: judgement,
            yOffset: yOffset,
            showNoteName: showNoteName,
            namingMode: namingMode
        )
    }
}
