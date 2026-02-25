import SwiftUI
import Charts

struct RecordsView: View {
    @State private var mode: TrainingModeRecord = .levels
    @State private var scope: Scope = .day
    @StateObject private var store = RecordsStore.shared

    enum Scope: String, CaseIterable, Identifiable {
        case day
        case month
        var id: String { rawValue }

        var title: String {
            switch self {
            case .day: return "每天"
            case .month: return "每月"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            JellyCard(tint: KidTheme.primary) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center, spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(KidTheme.primary.opacity(0.18))
                                .frame(width: 56, height: 56)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                                )

                            Image(systemName: "chart.bar.xaxis")
                                .font(.system(size: 22, weight: .heavy))
                                .foregroundColor(Color.white.opacity(0.95))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("RECORDS")
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .foregroundColor(KidTheme.textOnCardSecondary)

                            Text("记录")
                                .font(.system(size: 26, weight: .heavy, design: .rounded))
                                .foregroundColor(KidTheme.textOnCardPrimary)
                        }

                        Spacer()
                    }

                    ModePicker(mode: $mode)

                    ScopePicker(scope: $scope)

                    let streak = store.streakDays(mode: mode)
                    let today = store.stats(mode: mode, date: Date())

                    HStack(spacing: 12) {
                        StatChip(title: "今日答题", value: "\(today.answered)")
                        StatChip(title: "今日正确率", value: "\(Int((today.accuracy * 100).rounded()))%")
                        StatChip(title: "连续天数", value: "\(streak)")
                    }

                    if scope == .day {
                        HeatmapGrid(mode: mode, days: store.lastNDays(mode: mode, n: 91))
                        DailyCharts(mode: mode)
                    } else {
                        MonthlyCharts(mode: mode)
                    }
                }
            }

            Text("说明：记录按本机时间统计；听音训练会按最终答对/答错计入（不区分是否点过显示答案）。")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(KidTheme.textOnBackgroundSecondary)
                .padding(.horizontal, 6)
        }
    }
}

private struct ModePicker: View {
    @Binding var mode: TrainingModeRecord

    var body: some View {
        HStack(spacing: 10) {
            ForEach(TrainingModeRecord.allCases) { m in
                let isSelected = (mode == m)
                Button(action: { mode = m }) {
                    Text(m.titleZH)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(isSelected ? KidTheme.textOnCardPrimary : KidTheme.textOnCardSecondary)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(isSelected ? KidTheme.primary.opacity(0.18) : Color.black.opacity(0.04))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(isSelected ? KidTheme.primary.opacity(0.55) : KidTheme.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct ScopePicker: View {
    @Binding var scope: RecordsView.Scope

    var body: some View {
        HStack(spacing: 10) {
            ForEach(RecordsView.Scope.allCases) { s in
                let isSelected = (scope == s)
                Button(action: { scope = s }) {
                    Text(s.title)
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundColor(isSelected ? KidTheme.textOnCardPrimary : KidTheme.textOnCardSecondary)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(isSelected ? KidTheme.accent.opacity(0.16) : Color.black.opacity(0.04))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(isSelected ? KidTheme.accent.opacity(0.55) : KidTheme.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct StatChip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundColor(KidTheme.textOnCardSecondary)
            Text(value)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundColor(KidTheme.textOnCardPrimary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.10))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct HeatmapGrid: View {
    let mode: TrainingModeRecord
    let days: [(Date, RecordsDayStats)]

    private func intensity(_ stats: RecordsDayStats) -> Double {
        // Use answered as intensity driver.
        let a = stats.answered
        if a <= 0 { return 0 }
        if a <= 3 { return 0.35 }
        if a <= 8 { return 0.60 }
        if a <= 15 { return 0.82 }
        return 1.0
    }

    var body: some View {
        let cal = Calendar.current
        let start = days.first?.0 ?? Date()
        let startWeekday = cal.component(.weekday, from: start) // 1..7 (Sun..Sat)
        let padLeading = (startWeekday + 5) % 7 // convert so Monday=0

        let padded: [(Date?, RecordsDayStats)] = Array(repeating: (nil, RecordsDayStats()), count: padLeading)
            + days.map { ($0.0 as Date?, $0.1) }

        let columns = Array(repeating: GridItem(.flexible(minimum: 6, maximum: 20), spacing: 6), count: 13)

        VStack(alignment: .leading, spacing: 10) {
            Text("最近 3 个月")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundColor(KidTheme.textOnCardPrimary)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(0..<91, id: \.self) { i in
                    let item = i < padded.count ? padded[i] : (nil, RecordsDayStats())
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.08 + 0.22 * intensity(item.1)))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                        .frame(height: 12)
                }
            }
        }
        .padding(.top, 4)
    }
}

private struct DailyCharts: View {
    let mode: TrainingModeRecord
    @StateObject private var store = RecordsStore.shared

    struct Point: Identifiable {
        let id = UUID()
        let date: Date
        let answered: Int
        let seconds: Int
        let accuracy: Double
    }

    private var points: [Point] {
        store.lastNDays(mode: mode, n: 30).map { d, s in
            Point(date: d, answered: s.answered, seconds: s.seconds, accuracy: s.accuracy)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("每天趋势（30 天）")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundColor(KidTheme.textOnCardPrimary)

            Chart(points) { p in
                BarMark(
                    x: .value("Date", p.date),
                    y: .value("Answered", p.answered)
                )
                .foregroundStyle(KidTheme.primary.opacity(0.35))

                LineMark(
                    x: .value("Date", p.date),
                    y: .value("Accuracy", p.accuracy)
                )
                .foregroundStyle(KidTheme.textOnCardPrimary.opacity(0.95))
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(Color.black.opacity(0.08))
                    AxisValueLabel().foregroundStyle(KidTheme.textOnCardSecondary)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(Color.black.opacity(0.08))
                    AxisValueLabel().foregroundStyle(KidTheme.textOnCardSecondary)
                }
            }
            .chartYScale(domain: 0...max(1, (points.map { $0.answered }.max() ?? 1)))
            .frame(height: 160)
            .padding(.vertical, 6)
        }
    }
}

private struct MonthlyCharts: View {
    let mode: TrainingModeRecord
    @StateObject private var store = RecordsStore.shared

    struct MonthPoint: Identifiable {
        let id = UUID()
        let monthStart: Date
        let answered: Int
        let seconds: Int
        let accuracy: Double
    }

    private var points: [MonthPoint] {
        store.months(mode: mode, count: 12).map { d, s in
            MonthPoint(monthStart: d, answered: s.answered, seconds: s.seconds, accuracy: s.accuracy)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("每月趋势（12 个月）")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundColor(KidTheme.textOnCardPrimary)

            Chart(points) { p in
                BarMark(
                    x: .value("Month", p.monthStart, unit: .month),
                    y: .value("Answered", p.answered)
                )
                .foregroundStyle(KidTheme.primary.opacity(0.35))

                LineMark(
                    x: .value("Month", p.monthStart, unit: .month),
                    y: .value("Accuracy", p.accuracy)
                )
                .foregroundStyle(KidTheme.textOnCardPrimary.opacity(0.95))
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(Color.black.opacity(0.08))
                    AxisValueLabel().foregroundStyle(KidTheme.textOnCardSecondary)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(Color.black.opacity(0.08))
                    AxisValueLabel().foregroundStyle(KidTheme.textOnCardSecondary)
                }
            }
            .frame(height: 170)
            .padding(.vertical, 6)
        }
    }
}
