import SwiftUI
import Charts

struct RecordsView: View {
    @State private var tab: RecordsTab = .checkIn

    enum RecordsTab: String, CaseIterable, Identifiable {
        case checkIn
        case performance

        var id: String { rawValue }

        var title: String {
            switch self {
            case .checkIn: return "打卡"
            case .performance: return "成绩"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            JellyCard(tint: KidTheme.primary) {
                VStack(alignment: .leading, spacing: 12) {
                    RecordsTabPicker(tab: $tab)

                    switch tab {
                    case .checkIn:
                        CheckInTabView()
                    case .performance:
                        PerformanceTabView()
                    }
                }
            }

            Text("说明：记录按本机时间统计；可在打卡页删除单次训练记录。")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(KidTheme.textOnBackgroundSecondary)
                .padding(.horizontal, 6)
        }
    }
}

private struct RecordsTabPicker: View {
    @Binding var tab: RecordsView.RecordsTab

    var body: some View {
        HStack(spacing: 10) {
            ForEach(RecordsView.RecordsTab.allCases) { t in
                let isSelected = (tab == t)
                Button(action: { tab = t }) {
                    Text(t.title)
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

// MARK: - Check-in Tab

private struct CheckInTabView: View {
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            JellyCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("日历")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(KidTheme.textOnCardPrimary)

                    MonthCalendarPager(selectedDate: $selectedDate)
                }
            }

            JellyCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("记录")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundColor(KidTheme.textOnCardPrimary)

                        Spacer()

                        Text(selectedDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(KidTheme.textOnCardSecondary)
                    }

                    SessionListView(date: selectedDate)
                }
            }
        }
    }
}

private struct MonthCalendarPager: View {
    @Binding var selectedDate: Date
    @State private var index: Int = 11

    private var monthStarts: [Date] {
        let cal = Calendar.current
        let now = Date()
        let comps = cal.dateComponents([.year, .month], from: now)
        let thisMonthStart = cal.date(from: comps) ?? cal.startOfDay(for: now)
        return (0..<12).compactMap { i in
            cal.date(byAdding: .month, value: -(11 - i), to: thisMonthStart)
        }
    }

    var body: some View {
        let starts = monthStarts
        let safeIndex = min(max(0, index), max(0, starts.count - 1))

        TabView(selection: Binding(
            get: { safeIndex },
            set: { index = $0 }
        )) {
            ForEach(Array(starts.enumerated()), id: \.offset) { i, start in
                MonthCalendarPage(monthStart: start, selectedDate: $selectedDate)
                    .tag(i)
                    .padding(.top, 2)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 220)
        .onAppear {
            index = max(0, starts.count - 1)
        }
    }
}

private struct MonthCalendarPage: View {
    let monthStart: Date
    @Binding var selectedDate: Date
    @StateObject private var store = RecordsStore.shared

    private func title(for monthStart: Date) -> String {
        let cal = Calendar.current
        let y = cal.component(.year, from: monthStart)
        let m = cal.component(.month, from: monthStart)
        return String(format: "%04d-%02d", y, m)
    }

    private func dotColor(for mode: TrainingModeRecord) -> Color {
        switch mode {
        case .levels: return KidTheme.primary
        case .listen: return KidTheme.accent
        case .songs: return KidTheme.success
        case .practice: return KidTheme.userInput
        }
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

                HStack(spacing: 8) {
                    ForEach(TrainingModeRecord.allCases) { m in
                        Circle()
                            .fill(dotColor(for: m).opacity(0.85))
                            .frame(width: 7, height: 7)
                    }
                }

                Text("完成1次")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(KidTheme.textOnCardSecondary)
            }
            .frame(maxWidth: .infinity)

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
                    MonthDayCell(
                        date: d,
                        isSelected: d.map { cal.isDate($0, inSameDayAs: selectedDate) } ?? false,
                        dotColors: d.map { date in
                            TrainingModeRecord.allCases.compactMap { mode -> Color? in
                                let stats = store.stats(mode: mode, date: date)
                                let checked = (stats.answered > 0) || (stats.seconds > 0)
                                return checked ? dotColor(for: mode) : nil
                            }
                        } ?? [],
                        onTap: {
                            if let date = d {
                                selectedDate = cal.startOfDay(for: date)
                            }
                        }
                    )
                    .opacity(d == nil ? 0.0 : 1.0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 4)
    }
}

private struct MonthDayCell: View {
    let date: Date?
    let isSelected: Bool
    let dotColors: [Color]
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(date.map { String(Calendar.current.component(.day, from: $0)) } ?? "")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundColor(isSelected ? KidTheme.textOnCardPrimary : KidTheme.textOnCardSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(isSelected ? KidTheme.primary.opacity(0.16) : Color.clear)
                    .cornerRadius(8)

                HStack(spacing: 2) {
                    ForEach(0..<4, id: \.self) { i in
                        Circle()
                            .fill(i < dotColors.count ? dotColors[i].opacity(0.90) : Color.clear)
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(height: 6)
            }
            .frame(height: 28)
        }
        .buttonStyle(.plain)
        .disabled(date == nil)
    }
}

private struct SessionListView: View {
    let date: Date
    @StateObject private var store = RecordsStore.shared

    private func fmtSeconds(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let m = s / 60
        let r = s % 60
        if m > 0 { return String(format: "%d:%02d", m, r) }
        return String(format: "0:%02d", r)
    }

    var body: some View {
        let items = store.sessions(on: date)

        if items.isEmpty {
            Text("当天暂无记录")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(KidTheme.textOnCardSecondary)
                .padding(.vertical, 10)
        } else {
            VStack(spacing: 8) {
                ForEach(items) { s in
                    HStack(spacing: 10) {
                        Text(s.mode.titleZH)
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundColor(KidTheme.textOnCardPrimary)
                            .frame(width: 64, alignment: .leading)

                        VStack(alignment: .leading, spacing: 2) {
                            let pct = Int((s.accuracy * 100).rounded())
                            Text("\(s.answered)题  ·  \(pct)%  ·  \(fmtSeconds(s.seconds))")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(KidTheme.textOnCardSecondary)
                            Text(s.startedAt.formatted(date: .omitted, time: .shortened))
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(KidTheme.textOnCardSecondary.opacity(0.75))
                        }

                        Spacer()

                        Button(role: .destructive, action: {
                            store.deleteSession(id: s.id)
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundColor(KidTheme.danger)
                                .padding(8)
                                .background(KidTheme.danger.opacity(0.10))
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
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
            }
        }
    }
}

// MARK: - Performance Tab

private struct PerformanceTabView: View {
    @State private var mode: TrainingModeRecord = .levels
    @State private var scope: RecordsScope = .day
    @StateObject private var store = RecordsStore.shared

    enum RecordsScope: String, CaseIterable, Identifiable {
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
        VStack(alignment: .leading, spacing: 12) {
            ModePicker(mode: $mode)
            ScopePicker(scope: $scope)

            let today = store.stats(mode: mode, date: Date())
            let streak = store.streakDays(mode: mode)

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
                DailyCharts(mode: mode)
            case .week:
                WeeklyAccuracyChart(mode: mode)
            case .month:
                MonthlyAccuracyChart(mode: mode)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
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

private struct ScopePicker: View {
    @Binding var scope: PerformanceTabView.RecordsScope

    var body: some View {
        HStack(spacing: 10) {
            ForEach(PerformanceTabView.RecordsScope.allCases) { s in
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

private struct DailyCharts: View {
    let mode: TrainingModeRecord
    @StateObject private var store = RecordsStore.shared

    struct Point: Identifiable {
        let id = UUID()
        let date: Date
        let answered: Int
        let accuracy: Double
    }

    private var points: [Point] {
        store.lastNDays(mode: mode, n: 30).map { d, s in
            Point(date: d, answered: s.answered, accuracy: s.accuracy)
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
            .chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: 60 * 60 * 24 * 10)
            .chartScrollTargetBehavior(
                .valueAligned(matching: DateComponents(day: 1))
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
            .frame(height: 150)
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
    }

    private var points: [WeekPoint] {
        store.weeks(mode: mode, count: 12).map { d, s in
            WeekPoint(weekStart: d, accuracy: s.accuracy)
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
    }

    private var points: [MonthPoint] {
        store.months(mode: mode, count: 12).map { d, s in
            MonthPoint(monthStart: d, accuracy: s.accuracy)
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
