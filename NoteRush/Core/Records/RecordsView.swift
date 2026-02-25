import SwiftUI
import Charts

struct RecordsView: View {
    @State private var mode: TrainingModeRecord = .levels
    @State private var scope: Scope = .day
    @StateObject private var store = RecordsStore.shared

    enum Scope: String, CaseIterable, Identifiable {
        case day
        case week
        case month
        var id: String { rawValue }

        var title: String {
            switch self {
            case .day: return "每天"
            case .week: return "每周"
            case .month: return "每月"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            JellyCard(tint: KidTheme.primary) {
                VStack(alignment: .leading, spacing: 10) {
                    // Title header removed per design direction (keep the card clean)

                ModePicker(mode: $mode)

                    TabView(selection: $mode) {
                        ForEach(TrainingModeRecord.allCases) { m in
                            RecordsModePage(mode: m, scope: $scope)
                                .tag(m)
                                .padding(.top, 6)
                                .padding(.horizontal, 1)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    // Page-style TabView needs an explicit height in a VStack; otherwise it may collapse to 0.
                    // Make it tall enough that Weekly/Monthly views can show their chart without being cut off.
                    .frame(height: 600)
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
                        .padding(.vertical, 8)
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
        VStack(alignment: .leading, spacing: 12) {
                ScopePicker(scope: $scope)

                let today = store.stats(mode: mode, date: Date())
                let streak = store.streakDays(mode: mode)

                // Accuracy metrics
                // - 日视图：按“每天”统计
                // - 周视图：按“每周汇总”统计（每周一个点）
                // - 月视图：按“每月汇总”统计（每个月一个点）
                let modeDaysDict = store.days[mode.rawValue] ?? [:]
                let dayStats = Array(modeDaysDict.values)

                let weekStats: [RecordsDayStats] = store.weeks(mode: mode, count: 24)
                    .map { $0.1 }

                let monthStats: [RecordsDayStats] = store.months(mode: mode, count: 36)
                    .map { $0.1 }

                let sourceStats: [RecordsDayStats] = {
                    switch scope {
                    case .day: return dayStats
                    case .week: return weekStats
                    case .month: return monthStats
                    }
                }()

                let totalAnswered = sourceStats.reduce(0) { $0 + $1.answered }
                let totalCorrect = sourceStats.reduce(0) { $0 + $1.correct }
                let avgAccuracy = totalAnswered > 0 ? (Double(totalCorrect) / Double(totalAnswered)) : 0

                let bestAccuracy = sourceStats
                    .filter { $0.answered > 0 }
                    .map { $0.accuracy }
                    .max() ?? 0

                let statColumns: [GridItem] = [
                    GridItem(.flexible(minimum: 120), spacing: 10),
                    GridItem(.flexible(minimum: 120), spacing: 10)
                ]

                LazyVGrid(columns: statColumns, spacing: 10) {
                    StatChip(title: "测试音符", value: "\(today.answered)")
                    StatChip(title: "连续天数", value: "\(streak)")
                    StatChip(title: "最好正确率", value: "\(Int((bestAccuracy * 100).rounded()))%")
                    StatChip(title: "平均正确率", value: "\(Int((avgAccuracy * 100).rounded()))%")
                }

                switch scope {
                case .day:
                    CheckInTodayRow()
                case .week:
                    CheckInWeekPager()
                        // Force re-init when switching into this scope so the pager jumps back to the current week.
                        .id("week-\(mode.rawValue)-\(scope.rawValue)")
                    WeeklyAccuracyChart(mode: mode)
                case .month:
                    CheckInMonthPager()
                        // Force re-init when switching into this scope so the pager jumps back to the current month.
                        .id("month-\(mode.rawValue)-\(scope.rawValue)")
                    MonthlyAccuracyChart(mode: mode)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.bottom, 8)
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
                        .padding(.vertical, 7)
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
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundColor(KidTheme.textOnCardPrimary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
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
    /// Check-in rule: completing at least one item counts as a check-in.
    static func checkedIn(_ stats: RecordsDayStats) -> Bool {
        // Prefer answered count; fall back to time in case a mode logs seconds without answers.
        (stats.answered > 0) || (stats.seconds > 0)
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

            Text("打卡：完成1次")
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
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
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
        .frame(height: 10)
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

        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title(for: monthStart))
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(KidTheme.textOnCardPrimary)

                Spacer(minLength: 8)

                CheckInLegendRow()
            }
            .frame(maxWidth: .infinity)

            // Weekday labels (use the same grid columns so the labels align with the check-in cells)
            LazyVGrid(columns: columns, spacing: 4) {
                let labels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                ForEach(0..<labels.count, id: \.self) { i in
                    Text(labels[i])
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundColor(KidTheme.textOnCardSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<dates.count, id: \.self) { i in
                    let d = dates[i]
                    let sLevels = d.map { store.stats(mode: .levels, date: $0) } ?? RecordsDayStats()
                    let sListen = d.map { store.stats(mode: .listen, date: $0) } ?? RecordsDayStats()

                    CheckInDayCell(
                        levelsOK: CheckInRule.checkedIn(sLevels),
                        listenOK: CheckInRule.checkedIn(sListen)
                    )
                    .frame(height: 12)
                    .opacity(d == nil ? 0.0 : 1.0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 4)
    }
}

private struct CheckInMonthPager: View {
    // Default to the newest page (current month).
    @State private var index: Int = 11

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
            .frame(height: 210)
            .onAppear {
                // Always jump back to the newest month when entering the Monthly scope.
                index = max(0, starts.count - 1)
            }
        }
    }
}

private struct CheckInWeekPage: View {
    let weekStart: Date
    @StateObject private var store = RecordsStore.shared

    private func title(for weekStart: Date) -> String {
        let cal = Calendar.current
        let y = cal.component(.year, from: weekStart)
        let m = cal.component(.month, from: weekStart)
        let d = cal.component(.day, from: weekStart)
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    var body: some View {
        let cal = Calendar.current
        let days: [Date] = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("周：\(title(for: weekStart))")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(KidTheme.textOnCardPrimary)
                Spacer(minLength: 8)
                CheckInLegendRow()
            }

            // Weekday labels (use the same grid columns so the labels align with the check-in cells)
            LazyVGrid(columns: columns, spacing: 4) {
                let labels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                ForEach(0..<labels.count, id: \.self) { i in
                    Text(labels[i])
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundColor(KidTheme.textOnCardSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<days.count, id: \.self) { i in
                    let d = days[i]
                    let sLevels = store.stats(mode: .levels, date: d)
                    let sListen = store.stats(mode: .listen, date: d)

                    CheckInDayCell(
                        levelsOK: CheckInRule.checkedIn(sLevels),
                        listenOK: CheckInRule.checkedIn(sListen)
                    )
                    .frame(height: 12)
                }
            }
        }
        .padding(.top, 4)
    }
}

private struct CheckInWeekPager: View {
    // Default to the newest page (current week).
    @State private var index: Int = 11

    private var weekStarts: [Date] {
        let cal = Calendar.current
        let now = Date()
        // Start of current week
        let startOfToday = cal.startOfDay(for: now)
        let weekday = cal.component(.weekday, from: startOfToday)
        let daysFromWeekStart = (weekday - cal.firstWeekday + 7) % 7
        let thisWeekStart = cal.date(byAdding: .day, value: -daysFromWeekStart, to: startOfToday) ?? startOfToday

        // 12 weeks, oldest -> newest
        return (0..<12).compactMap { i in
            cal.date(byAdding: .day, value: -7 * (11 - i), to: thisWeekStart)
        }
    }

    var body: some View {
        let starts = weekStarts
        let safeIndex = min(max(0, index), max(0, starts.count - 1))

        VStack(alignment: .leading, spacing: 10) {
            TabView(selection: Binding(
                get: { safeIndex },
                set: { index = $0 }
            )) {
                ForEach(Array(starts.enumerated()), id: \.offset) { i, start in
                    CheckInWeekPage(weekStart: start)
                        .tag(i)
                        .padding(.top, 2)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 120)
            .onAppear {
                // Always jump back to the newest week when entering the Weekly scope.
                index = max(0, starts.count - 1)
            }
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

private struct WeeklyAccuracyChart: View {
    let mode: TrainingModeRecord
    @StateObject private var store = RecordsStore.shared

    struct WeekPoint: Identifiable {
        let id = UUID()
        let weekStart: Date
        let accuracy: Double
        let answered: Int
    }

    private var points: [WeekPoint] {
        store.weeks(mode: mode, count: 12).map { d, s in
            WeekPoint(weekStart: d, accuracy: s.accuracy, answered: s.answered)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("正确率趋势")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundColor(KidTheme.textOnCardPrimary)

            Chart(points) { p in
                LineMark(
                    x: .value("Week", p.weekStart),
                    y: .value("Accuracy", p.accuracy)
                )
                .foregroundStyle(KidTheme.textOnCardPrimary.opacity(0.95))
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Week", p.weekStart),
                    y: .value("Accuracy", p.accuracy)
                )
                .foregroundStyle(KidTheme.accent.opacity(0.85))
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(Color.black.opacity(0.08))
                    AxisValueLabel().foregroundStyle(KidTheme.textOnCardSecondary)
                }
            }
            .chartXAxis {
                // Reduce label clutter: show one label every ~4 weeks, and use short format.
                AxisMarks(values: .stride(by: .weekOfYear, count: 4)) { _ in
                    AxisGridLine().foregroundStyle(Color.black.opacity(0.08))
                    AxisValueLabel(format: .dateTime.month().day())
                        .foregroundStyle(KidTheme.textOnCardSecondary)
                }
            }
            .chartYScale(domain: 0...1)
            .frame(height: 120)
            .padding(.vertical, 6)
        }
    }
}

private struct MonthlyAccuracyChart: View {
    let mode: TrainingModeRecord
    @StateObject private var store = RecordsStore.shared

    struct MonthPoint: Identifiable {
        let id = UUID()
        let monthStart: Date
        let accuracy: Double
        let answered: Int
    }

    private var points: [MonthPoint] {
        store.months(mode: mode, count: 12).map { d, s in
            MonthPoint(monthStart: d, accuracy: s.accuracy, answered: s.answered)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("正确率趋势")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundColor(KidTheme.textOnCardPrimary)

            Chart(points) { p in
                LineMark(
                    x: .value("Month", p.monthStart, unit: .month),
                    y: .value("Accuracy", p.accuracy)
                )
                .foregroundStyle(KidTheme.textOnCardPrimary.opacity(0.95))
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Month", p.monthStart, unit: .month),
                    y: .value("Accuracy", p.accuracy)
                )
                .foregroundStyle(KidTheme.accent.opacity(0.85))
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(Color.black.opacity(0.08))
                    AxisValueLabel().foregroundStyle(KidTheme.textOnCardSecondary)
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(Color.black.opacity(0.08))
                    AxisValueLabel().foregroundStyle(KidTheme.textOnCardSecondary)
                }
            }
            .chartYScale(domain: 0...1)
            .frame(height: 120)
            .padding(.vertical, 6)
        }
    }
}
