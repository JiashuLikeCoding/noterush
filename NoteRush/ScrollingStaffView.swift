import SwiftUI

struct ScrollingStaffView: View {
    @State private var clefCollapsed: Bool = false

    // Delay notes + scrolling start.
    private let introDelaySeconds: TimeInterval = 2.0
    @State private var showNotes: Bool = false
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
    let noteRhythm: NoteRhythm?
    let bpm: Double?
    let beatsPerBar: Double?

    var body: some View {
        GeometryReader { proxy in
            let layout = StaffLayout(size: proxy.size, mode: clefMode)
            let referenceMetrics = layout.single.metrics
            // Product direction: judgement line stays near the far-left side of the staff,
            // with a visible inset from the edge.
            let leftInset = max(36, referenceMetrics.lineSpacing * 2.5)
            let rawJudgementX = min(referenceMetrics.rightMargin - 1, referenceMetrics.leftMargin + leftInset)
            let judgementX = StaffMetrics.roundToPixel(rawJudgementX, scale: referenceMetrics.pixelScale)
            // Right-to-left scrolling: notes travel from the right edge toward the left judgement line.
            let rightSpan = max(1, referenceMetrics.rightMargin - judgementX)
            let pixelsPerSecond = rightSpan / CGFloat(scrollConfig.leadTime)
            let speedScale = pixelsPerSecond * CGFloat(scrollSpeedMultiplier)
            let leftLimit = referenceMetrics.leftMargin - 24
            let rightLimit = referenceMetrics.rightMargin + 24
            let staffYBounds: (top: CGFloat, bottom: CGFloat) = {
                if clefMode == .grand, let treble = layout.treble, let bass = layout.bass {
                    return (
                        top: treble.metrics.y(for: treble.metrics.topStaffLineIndex) + treble.yOffset,
                        bottom: bass.metrics.y(for: bass.metrics.bottomStaffLineIndex) + bass.yOffset
                    )
                }
                return (
                    top: referenceMetrics.y(for: referenceMetrics.topStaffLineIndex),
                    bottom: referenceMetrics.y(for: referenceMetrics.bottomStaffLineIndex)
                )
            }()
            ZStack {
                if clefMode == .grand {
                    if let treble = layout.treble {
                        ClefIconView(clef: .treble, metrics: treble.metrics, yOffset: treble.yOffset, collapsed: clefCollapsed, collapsedIndex: 0)
                            .zIndex(-1)
                    }
                    if let bass = layout.bass {
                        ClefIconView(clef: .bass, metrics: bass.metrics, yOffset: bass.yOffset, collapsed: clefCollapsed, collapsedIndex: 1)
                            .zIndex(-1)
                    }
                } else if clefMode == .bass {
                    ClefIconView(clef: .bass, metrics: referenceMetrics, yOffset: 0, collapsed: clefCollapsed, collapsedIndex: 0)
                        .zIndex(-1)
                } else {
                    ClefIconView(clef: .treble, metrics: referenceMetrics, yOffset: 0, collapsed: clefCollapsed, collapsedIndex: 0)
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

                if let bpm, let beatsPerBar, beatsPerBar > 0 {
                    let secondsPerBeat = 60.0 / max(10.0, bpm)
                    let barDuration = secondsPerBeat * beatsPerBar

                    if secondsPerBeat > 0, barDuration > 0 {
                        let minVisibleTime = currentTime + TimeInterval((leftLimit - judgementX) / speedScale)
                        let maxVisibleTime = currentTime + TimeInterval((rightLimit - judgementX) / speedScale)

                        // Standard notation: show ONLY barlines; avoid full beat grid (looks like a piano-roll).
                        // If you want beat guidance later, we'll draw small tick marks instead of full-height lines.
                        let startBar = max(0, Int(floor(minVisibleTime / barDuration)) - 2)
                        let endBar = max(startBar, Int(ceil(maxVisibleTime / barDuration)) + 2)

                        ForEach(startBar...endBar, id: \.self) { barIndex in
                            let barTime = TimeInterval(barIndex) * barDuration
                            let rawX = judgementX + CGFloat(barTime - currentTime) * speedScale
                            // Engraving spacing: keep barlines away from noteheads.
                            let barVisualOffset = max(10, referenceMetrics.lineSpacing * 0.9)
                            let x = StaffMetrics.roundToPixel(rawX - barVisualOffset, scale: referenceMetrics.pixelScale)

                            if x >= leftLimit && x <= rightLimit {
                                Path { path in
                                    path.move(to: CGPoint(x: x, y: staffYBounds.bottom))
                                    path.addLine(to: CGPoint(x: x, y: staffYBounds.top))
                                }
                                .stroke(
                                    Color.black.opacity(0.45),
                                    style: StrokeStyle(lineWidth: max(2, referenceMetrics.strokeWidth * 1.6))
                                )
                                .zIndex(0.75)
                            }
                        }
                    }
                }

                Path { path in
                    path.move(to: CGPoint(x: judgementX, y: staffYBounds.bottom))
                    path.addLine(to: CGPoint(x: judgementX, y: staffYBounds.top))
                }
                .stroke(
                    Color.black.opacity(0.6),
                    style: StrokeStyle(lineWidth: referenceMetrics.strokeWidth, dash: [6, 6])
                )
                .zIndex(1)

                if showNotes {
                    ForEach(events, id: \.id) { (event: SongNoteEvent) in
                        let timeOffset = event.time - currentTime
                        // Right -> left:
                        // future note (timeOffset > 0) sits to the right, then moves left as time advances.
                        let rawXPosition = judgementX + CGFloat(timeOffset) * speedScale
                        let xPosition = StaffMetrics.roundToPixel(rawXPosition, scale: referenceMetrics.pixelScale)

                        if xPosition >= leftLimit && xPosition <= rightLimit {
                            let baseColor = baseNoteColor(for: event.note, isTarget: event.isTarget)
                            let displayColor = noteColor(for: event.judgement, baseColor: baseColor)
                            let noteSlot = layout.slot(for: event.note.clef)

                            let displayRhythm = noteRhythm ?? event.rhythm
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

            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                // Delay notes visibility; the view model clock is also delayed in SongModeView
                // so judgement and visuals stay aligned.
                clefCollapsed = false
                showNotes = false

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.88)) {
                        clefCollapsed = true
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + introDelaySeconds) {
                    showNotes = true
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Scrolling staff")
    }

    private func noteColor(for judgement: Judgement?, baseColor: Color) -> Color {
        // User requirement:
        // - correct: entire note becomes deep purple (matches UI)
        // - wrong: entire note becomes red
        guard let judgement else { return baseColor }
        switch judgement {
        case .perfect:
            return KidTheme.userInput
        case .miss:
            return KidTheme.danger
        }
    }

    private func baseNoteColor(for note: StaffNote, isTarget: Bool) -> Color {
        // Target notes can be colored by letter; user input notes should match the global UI purple.
        if !isTarget {
            return KidTheme.userInput
        }
        return useColoredNotes ? CuteTheme.noteColor(for: note.letter) : Color.black
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
