import Foundation
import SwiftUI
import Combine

// MARK: - Records

enum TrainingModeRecord: String, CaseIterable, Identifiable {
    case levels
    case listen
    case songs
    case practice

    var id: String { rawValue }

    var titleZH: String {
        switch self {
        case .levels: return "闯关"
        case .listen: return "听音"
        case .songs: return "歌曲"
        case .practice: return "自由练习"
        }
    }

    var titleEN: String {
        switch self {
        case .levels: return "LEVEL"
        case .listen: return "LISTEN"
        case .songs: return "SONG"
        case .practice: return "PRACTICE"
        }
    }
}

struct RecordsDayStats: Codable, Hashable {
    var answered: Int
    var correct: Int
    var seconds: Int

    init(answered: Int = 0, correct: Int = 0, seconds: Int = 0) {
        self.answered = answered
        self.correct = correct
        self.seconds = seconds
    }

    var accuracy: Double {
        guard answered > 0 else { return 0 }
        return Double(correct) / Double(answered)
    }
}

final class RecordsStore: ObservableObject {
    static let shared = RecordsStore()

    private let storageKey = "records.v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// modeRaw -> yyyy-MM-dd -> stats
    @Published private(set) var days: [String: [String: RecordsDayStats]] = [:]

    private init() {
        load()
    }

    // MARK: - Public API

    func logAnswer(mode: TrainingModeRecord, correct: Bool, date: Date = Date()) {
        let key = dateKey(for: date)
        var modeDays = days[mode.rawValue, default: [:]]
        var stats = modeDays[key] ?? RecordsDayStats()
        stats.answered += 1
        if correct { stats.correct += 1 }
        modeDays[key] = stats
        days[mode.rawValue] = modeDays
        save()
    }

    func addSeconds(mode: TrainingModeRecord, seconds: Int, date: Date = Date()) {
        guard seconds > 0 else { return }
        let key = dateKey(for: date)
        var modeDays = days[mode.rawValue, default: [:]]
        var stats = modeDays[key] ?? RecordsDayStats()
        stats.seconds += seconds
        modeDays[key] = stats
        days[mode.rawValue] = modeDays
        save()
    }

    func stats(mode: TrainingModeRecord, date: Date) -> RecordsDayStats {
        let key = dateKey(for: date)
        return days[mode.rawValue]?[key] ?? RecordsDayStats()
    }

    func streakDays(mode: TrainingModeRecord, upTo date: Date = Date()) -> Int {
        var streak = 0
        var cursor = Calendar.current.startOfDay(for: date)
        while true {
            let s = stats(mode: mode, date: cursor)
            if s.answered > 0 || s.seconds > 0 {
                streak += 1
            } else {
                break
            }
            guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    func lastNDays(mode: TrainingModeRecord, n: Int, endingAt date: Date = Date()) -> [(Date, RecordsDayStats)] {
        let end = Calendar.current.startOfDay(for: date)
        return (0..<n).compactMap { i in
            guard let d = Calendar.current.date(byAdding: .day, value: -i, to: end) else { return nil }
            return (d, stats(mode: mode, date: d))
        }.reversed()
    }

    func months(mode: TrainingModeRecord, count: Int = 12, endingAt date: Date = Date()) -> [(Date, RecordsDayStats)] {
        let cal = Calendar.current
        let components = cal.dateComponents([.year, .month], from: date)
        let monthStart = cal.date(from: components) ?? cal.startOfDay(for: date)

        return (0..<count).compactMap { i in
            guard let start = cal.date(byAdding: .month, value: -i, to: monthStart) else { return nil }
            let range = cal.range(of: .day, in: .month, for: start) ?? 1..<2
            var agg = RecordsDayStats()
            for day in range {
                var dc = cal.dateComponents([.year, .month, .day], from: start)
                dc.day = day
                if let d = cal.date(from: dc) {
                    let s = stats(mode: mode, date: d)
                    agg.answered += s.answered
                    agg.correct += s.correct
                    agg.seconds += s.seconds
                }
            }
            return (start, agg)
        }.reversed()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            days = [:]
            return
        }
        do {
            days = try decoder.decode([String: [String: RecordsDayStats]].self, from: data)
        } catch {
            days = [:]
        }
    }

    private func save() {
        do {
            let data = try encoder.encode(days)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            // ignore
        }
    }

    private func dateKey(for date: Date) -> String {
        let cal = Calendar.current
        let dc = cal.dateComponents([.year, .month, .day], from: date)
        let y = dc.year ?? 0
        let m = dc.month ?? 0
        let d = dc.day ?? 0
        return String(format: "%04d-%02d-%02d", y, m, d)
    }
}

// MARK: - Session time tracking

private enum RecordsSessionClock {
    static var starts: [String: CFTimeInterval] = [:]
}

struct RecordsSessionModifier: ViewModifier {
    let mode: TrainingModeRecord

    func body(content: Content) -> some View {
        content
            .onAppear {
                RecordsSessionClock.starts[mode.rawValue] = CACurrentMediaTime()
            }
            .onDisappear {
                let now = CACurrentMediaTime()
                let start = RecordsSessionClock.starts[mode.rawValue] ?? now
                RecordsSessionClock.starts[mode.rawValue] = nil
                let seconds = max(0, Int((now - start).rounded()))
                RecordsStore.shared.addSeconds(mode: mode, seconds: seconds)
            }
    }
}

extension View {
    func recordSession(mode: TrainingModeRecord) -> some View {
        modifier(RecordsSessionModifier(mode: mode))
    }
}
