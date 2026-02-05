import SwiftUI

struct NoteGlyphView: View {
    let note: StaffNote
    let metrics: StaffMetrics
    let xPosition: CGFloat
    let color: Color
    let rhythm: NoteRhythm
    let scale: CGFloat
    let flashCorrect: Bool
    let yOffset: CGFloat
    let showNoteName: Bool
    let namingMode: NoteNamingMode

    init(
        note: StaffNote,
        metrics: StaffMetrics,
        xPosition: CGFloat,
        color: Color,
        rhythm: NoteRhythm,
        scale: CGFloat = 1.0,
        flashCorrect: Bool = false,
        yOffset: CGFloat = 0,
        showNoteName: Bool = false,
        namingMode: NoteNamingMode = .letters
    ) {
        self.note = note
        self.metrics = metrics
        self.xPosition = xPosition
        self.color = color
        self.rhythm = rhythm
        self.scale = scale
        self.flashCorrect = flashCorrect
        self.yOffset = yOffset
        self.showNoteName = showNoteName
        self.namingMode = namingMode
    }

    var body: some View {
        let yPosition = metrics.y(for: note.index)
        let headWidth = StaffMetrics.roundToPixel(metrics.lineSpacing * 1.2, scale: metrics.pixelScale)
        let headHeight = StaffMetrics.roundToPixel(metrics.lineSpacing * 0.9, scale: metrics.pixelScale)
        let stemHeight = StaffMetrics.roundToPixel(metrics.lineSpacing * 2.6, scale: metrics.pixelScale)
        let stemWidth = metrics.strokeWidth
        let stemUp = note.index <= 6
        let stemXOffset = stemUp ? (headWidth * 0.45) : (-headWidth * 0.45)
        let stemYOffset = stemUp ? (-stemHeight / 2 + headHeight * 0.15)
            : (stemHeight / 2 - headHeight * 0.15)
        let isOpenHead = rhythm == .whole || rhythm == .half
        let showStem = rhythm != .whole
        let headRotation = Angle.degrees(-12)
        let headStrokeWidth = max(metrics.strokeWidth * 1.3, 1)

        let ledgerIndices = metrics.ledgerLineIndices(for: note.index)
        let showLineThroughHead = metrics.staffLineIndices.contains(note.index) || note.isLedgerLine

        ZStack {
            ForEach(ledgerIndices, id: \.self) { ledgerIndex in
                Rectangle()
                    // Ledger lines should match staff line color (not note color).
                    .fill(CuteTheme.staffLineColor)
                    .frame(width: headWidth * 1.6, height: metrics.strokeWidth)
                    .offset(y: metrics.y(for: ledgerIndex) - yPosition)
            }

            if isOpenHead {
                Ellipse()
                    .fill(CuteTheme.cardBackground)
                    .frame(width: headWidth, height: headHeight)
                    .rotationEffect(headRotation)

                Ellipse()
                    .stroke(color, lineWidth: headStrokeWidth)
                    .frame(width: headWidth, height: headHeight)
                    .rotationEffect(headRotation)
            } else {
                Ellipse()
                    .fill(color)
                    .frame(width: headWidth, height: headHeight)
                    .rotationEffect(headRotation)
            }

            if showStem {
                Rectangle()
                    .fill(color)
                    .frame(width: stemWidth, height: stemHeight)
                    .offset(x: stemXOffset, y: stemYOffset)
            }

            if showLineThroughHead {
                Rectangle()
                    // Staff line running through the note head should match staff color.
                    .fill(CuteTheme.staffLineColor)
                    .frame(width: headWidth * 1.6, height: metrics.strokeWidth)
            }

            Ellipse()
                .stroke(Color.green, lineWidth: 3)
                .frame(width: headWidth * 1.1, height: headHeight * 1.1)
                .rotationEffect(headRotation)
                .opacity(flashCorrect ? 0.9 : 0)
                .animation(.easeOut(duration: 0.2), value: flashCorrect)

            if showNoteName {
                Text(note.letter.displayName(for: namingMode))
                    .font(.system(size: headHeight * 0.9, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                    .offset(x: headWidth * 1.4)
            }
        }
        // Important: scale the glyph first, then position it on the staff.
        .scaleEffect(scale)
        .position(x: xPosition, y: yPosition + yOffset)
        .animation(.easeOut(duration: 0.2), value: scale)
    }
}
