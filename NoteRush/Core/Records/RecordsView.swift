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

                    TabView(selection: $mode) {
                        ForEach(TrainingModeRecord.allCases) { m in
                            RecordsModePage(mode: m, scope: $scope)
                                .tag(m)
                                .padding(.top, 10)
                                .padding(.horizontal, 1)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    // Page-style TabView needs an explicit height in a VStack; otherwise it may collapse to 0.
                    .frame(height: scope == .day ? 380 : 420)
                    .frame(maxWidth: .infinity)
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

private struct RecordsModePage: View {
    let mode: TrainingModeRecord
    @Binding var scope: RecordsView.Scope
    @StateObject private var store = RecordsStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScopePicker(scope: $scope)

                let today = store.stats(mode: mode, date: Date())
                let streak = store.streakDays(mode: mode)

                // Accuracy metrics
                // - 日视图：按“每天”统计
                // - 月视图：按“每月汇总”统计（每个月一个点）
                let modeDaysDict = store.days[mode.rawValue] ?? [:]
                let dayStats = Array(modeDaysDict.values)

                let monthStats: [RecordsDayStats] = store.months(mode: mode, count: 36)
                    .map { $0.1 }

                let sourceStats = (scope == .day) ? dayStats : monthStats

                let totalAnswered = sourceStats.reduce(0) { $0 + $1.answered }
                let totalCorrect = sourceStats.reduce(0) { $0 + $1.correct }
                let avgAccuracy = totalAnswered > 0 ? (Double(totalCorrect) / Double(totalAnswered)) : 0

                let bestAccuracy = sourceStats
                    .filter { $0.answered > 0 }
                    .map { $0.accuracy }
                    .max() ?? 0

                let statColumns: [GridItem] = [
                    GridItem(.flexible(minimum: 120), spacing: 12),
                    GridItem(.flexible(minimum: 120), spacing: 12)
                ]

                LazyVGrid(columns: statColumns, spacing: 12) {
                    StatChip(title: "测试音符", value: "\(today.answered)")
                    StatChip(title: "连续天数", value: "\(streak)")
                    StatChip(title: "最好正确率", value: "\(Int((bestAccuracy * 100).rounded()))%")
                    StatChip(title: "平均正确率", value: "\(Int((avgAccuracy * 100).rounded()))%")
                }

                if scope == .day {
                    CheckInTodayRow()
                } else {
                    CheckInMonthPager()
                }
            }
            .padding(.bottom, 10)
        }
        .scrollIndicators(.hidden)
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

private enum CheckInRule {
    static let secondsThreshold = 15 * 60

    static func checkedIn(_ stats: RecordsDayStats) -> Bool {
        stats.seconds >= secondsThreshold
    }
}

private struct CheckInLegendRow: View {
    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(KidTheme.primary.opacity(0.85))
                    .frame(width: 14, height: 10)
                Text("闯关")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(KidTheme.textOnCardSecondary)
            }

            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(KidTheme.accent.opacity(0.85))
                    .frame(width: 14, height: 10)
                Text("听音")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(KidTheme.textOnCardSecondary)
            }

            Spacer()

            Text("打卡：≥15分钟")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundColor(KidTheme.textOnCardSecondary)
        }
    }
}

private struct CheckInTodayRow: View {
    @StateObject private var store = RecordsStore.shared

    private func pill(title: String, ok: Bool, color: Color) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color.opacity(0.85))
                .frame(width: 14, height: 10)
            Text(title)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(KidTheme.textOnCardPrimary)
            Spacer()
            Text(ok ? "已打卡" : "未打卡")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(ok ? KidTheme.textOnCardPrimary : KidTheme.textOnCardSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(ok ? color.opacity(0.18) : Color.black.opacity(0.04))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(ok ? color.opacity(0.70) : KidTheme.border, lineWidth: 1)
                )
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.10))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }

    var body: some View {
        let todayLevels = store.stats(mode: .levels, date: Date())
        let todayListen = store.stats(mode: .listen, date: Date())
        let okLevels = CheckInRule.checkedIn(todayLevels)
        let okListen = CheckInRule.checkedIn(todayListen)

        VStack(alignment: .leading, spacing: 10) {
            Text("今日打卡")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundColor(KidTheme.textOnCardPrimary)

            HStack(spacing: 12) {
                pill(title: "闯关", ok: okLevels, color: KidTheme.primary)
                pill(title: "听音", ok: okListen, color: KidTheme.accent)
            }
        }
        .padding(.top, 2)
    }
}

private struct CheckInDayCell: View {
    let levelsOK: Bool
    let listenOK: Bool

    var body: some View {
        HStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 3)
                .fill(levelsOK ? KidTheme.primary.opacity(0.85) : Color.black.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(levelsOK ? KidTheme.primary.opacity(0.95) : Color.white.opacity(0.10), lineWidth: 1)
                )
            RoundedRectangle(cornerRadius: 3)
                .fill(listenOK ? KidTheme.accent.opacity(0.85) : Color.black.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(listenOK ? KidTheme.accent.opacity(0.95) : Color.white.opacity(0.10), lineWidth: 1)
                )
        }
        .frame(height: 12)
    }
}

private struct CheckInMonthPage: View {
    let monthStart: Date
    @StateObject private var store = RecordsStore.shared

    private func title(for monthStart: Date) -> String {
        let cal = Calendar.current
        let y = cal.component(.year, from: monthStart)
        let m = cal.component(.month, from: monthStart)
        return String(format: "%04d-%02d", y, m)
    }

    var body: some View {
        let cal = Calendar.current
        let range = cal.range(of: .day, in: .month, for: monthStart) ?? 1..<2

        let firstWeekday = cal.component(.weekday, from: monthStart) // 1..7
        let padLeading = (firstWeekday + 5) % 7 // Monday=0

        let dates: [Date?] = {
            var arr: [Date?] = Array(repeating: nil, count: padLeading)
            for day in range {
                var dc = cal.dateComponents([.year, .month, .day], from: monthStart)
                dc.day = day
                arr.append(cal.date(from: dc))
            }
            return arr
        }()

        let columns = Array(repeating: GridItem(.flexible(minimum: 8, maximum: 24), spacing: 6), count: 7)

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title(for: monthStart))
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundColor(KidTheme.textOnCardPrimary)

                Spacer(minLength: 8)

                CheckInLegendRow()
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(0..<dates.count, id: \.self) { i in
                    let d = dates[i]
                    let sLevels = d.map { store.stats(mode: .levels, date: $0) } ?? RecordsDayStats()
                    let sListen = d.map { store.stats(mode: .listen, date: $0) } ?? RecordsDayStats()

                    CheckInDayCell(
                        levelsOK: CheckInRule.checkedIn(sLevels),
                        listenOK: CheckInRule.checkedIn(sListen)
                    )
                    .frame(height: 14)
                    .opacity(d == nil ? 0.0 : 1.0)
                }
            }
        }
        .padding(.top, 4)
    }
}

private struct CheckInMonthPager: View {
    @State private var index: Int = 0

    private var monthStarts: [Date] {
        let cal = Calendar.current
        let now = Date()
        let comps = cal.dateComponents([.year, .month], from: now)
        let thisMonthStart = cal.date(from: comps) ?? cal.startOfDay(for: now)
        // 12 months, oldest -> newest
        return (0..<12).compactMap { i in
            cal.date(byAdding: .month, value: -(11 - i), to: thisMonthStart)
        }
    }

    var body: some View {
        let starts = monthStarts
        let safeIndex = min(max(0, index), max(0, starts.count - 1))

        VStack(alignment: .leading, spacing: 10) {
            TabView(selection: Binding(
                get: { safeIndex },
                set: { index = $0 }
            )) {
                ForEach(Array(starts.enumerated()), id: \.offset) { i, start in
                    CheckInMonthPage(monthStart: start)
                        .tag(i)
                        .padding(.top, 2)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 320)
        }
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
            // Allow swipe/drag to pan horizontally through time.
            .chartScrollableAxes(.horizontal)
            // Show ~10 days at a time; user can swipe for the rest.
            .chartXVisibleDomain(length: 60 * 60 * 24 * 10)
            .chartScrollTargetBehavior(
                .valueAligned(
                    matching: DateComponents(day: 1)
                )
            )
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
