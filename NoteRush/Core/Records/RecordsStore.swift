import Foundation
import SwiftUI
import Combine

// MARK: - Records

enum TrainingModeRecord: String, CaseIterable, Identifiable, Codable {
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

struct RecordsSession: Codable, Identifiable, Hashable {
    var id: UUID
    var mode: TrainingModeRecord
    var startedAt: Date
    var endedAt: Date?
    var answered: Int
    var correct: Int
    var seconds: Int

    init(id: UUID = UUID(), mode: TrainingModeRecord, startedAt: Date = Date()) {
        self.id = id
        self.mode = mode
        self.startedAt = startedAt
        self.endedAt = nil
        self.answered = 0
        self.correct = 0
        self.seconds = 0
    }

    var accuracy: Double {
        guard answered > 0 else { return 0 }
        return Double(correct) / Double(answered)
    }
}

final class RecordsStore: ObservableObject {
    static let shared = RecordsStore()

    private let storageKey = "records.v1" // aggregated by day
    private let sessionsKey = "records.sessions.v1" // session-level
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// modeRaw -> yyyy-MM-dd -> stats
    @Published private(set) var days: [String: [String: RecordsDayStats]] = [:]

    /// session list (source of truth)
    @Published private(set) var sessions: [RecordsSession] = []

    /// modeRaw -> active session id
    private var activeSessionIds: [String: UUID] = [:]

    private init() {
        load()
    }

    // MARK: - Public API

    @discardableResult
    func startSession(mode: TrainingModeRecord, startedAt: Date = Date()) -> UUID {
        let session = RecordsSession(mode: mode, startedAt: startedAt)
        sessions.append(session)
        activeSessionIds[mode.rawValue] = session.id
        recomputeDaysFromSessions()
        save()
        return session.id
    }

    func endSession(mode: TrainingModeRecord, endedAt: Date = Date()) {
        guard let id = activeSessionIds[mode.rawValue] else { return }
        if let idx = sessions.lastIndex(where: { $0.id == id }) {
            if sessions[idx].endedAt == nil {
                sessions[idx].endedAt = endedAt
            }
        }
        activeSessionIds[mode.rawValue] = nil
        recomputeDaysFromSessions()
        save()
    }

    func logAnswer(mode: TrainingModeRecord, correct: Bool, date: Date = Date()) {
        // Prefer writing into the active session.
        if let id = activeSessionIds[mode.rawValue], let idx = sessions.lastIndex(where: { $0.id == id }) {
            sessions[idx].answered += 1
            if correct { sessions[idx].correct += 1 }
        } else {
            // Fallback: create an implicit session so the day is still counted.
            let implicitId = startSession(mode: mode, startedAt: date)
            if let idx = sessions.lastIndex(where: { $0.id == implicitId }) {
                sessions[idx].answered += 1
                if correct { sessions[idx].correct += 1 }
                sessions[idx].endedAt = date
            }
        }

        recomputeDaysFromSessions()
        save()
    }

    func addSeconds(mode: TrainingModeRecord, seconds: Int, date: Date = Date()) {
        guard seconds > 0 else { return }

        if let id = activeSessionIds[mode.rawValue], let idx = sessions.lastIndex(where: { $0.id == id }) {
            sessions[idx].seconds += seconds
        } else {
            // If we only have time, create an implicit session.
            let implicitId = startSession(mode: mode, startedAt: date)
            if let idx = sessions.lastIndex(where: { $0.id == implicitId }) {
                sessions[idx].seconds += seconds
                sessions[idx].endedAt = date
            }
        }

        recomputeDaysFromSessions()
        save()
    }

    func deleteSession(id: UUID) {
        sessions.removeAll { $0.id == id }
        activeSessionIds = activeSessionIds.filter { $0.value != id }
        recomputeDaysFromSessions()
        save()
    }

    func sessions(on date: Date) -> [RecordsSession] {
        let key = dateKey(for: date)
        return sessions
            .filter { dateKey(for: $0.startedAt) == key }
            .sorted { ($0.startedAt) > ($1.startedAt) }
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

    func weeks(mode: TrainingModeRecord, count: Int = 12, endingAt date: Date = Date()) -> [(Date, RecordsDayStats)] {
        let cal = Calendar.current
        // Start of current week (use the user's locale firstWeekday)
        let startOfToday = cal.startOfDay(for: date)
        let weekday = cal.component(.weekday, from: startOfToday)
        let daysFromWeekStart = (weekday - cal.firstWeekday + 7) % 7
        let thisWeekStart = cal.date(byAdding: .day, value: -daysFromWeekStart, to: startOfToday) ?? startOfToday

        return (0..<count).compactMap { i in
            guard let start = cal.date(byAdding: .day, value: -(7 * i), to: thisWeekStart) else { return nil }
            var agg = RecordsDayStats()
            for dayOffset in 0..<7 {
                if let d = cal.date(byAdding: .day, value: dayOffset, to: start) {
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
        // Sessions are the source of truth.
        if let data = UserDefaults.standard.data(forKey: sessionsKey) {
            do {
                sessions = try decoder.decode([RecordsSession].self, from: data)
            } catch {
                sessions = []
            }
        } else {
            sessions = []
        }

        // Legacy days (v1) – keep as fallback only.
        if sessions.isEmpty, let data = UserDefaults.standard.data(forKey: storageKey) {
            do {
                days = try decoder.decode([String: [String: RecordsDayStats]].self, from: data)
            } catch {
                days = [:]
            }
        } else {
            recomputeDaysFromSessions()
        }
    }

    private func save() {
        do {
            let sessionsData = try encoder.encode(sessions)
            UserDefaults.standard.set(sessionsData, forKey: sessionsKey)
        } catch {
            // ignore
        }

        // Also store aggregates for fast UI reads.
        do {
            let data = try encoder.encode(days)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            // ignore
        }
    }

    private func recomputeDaysFromSessions() {
        var next: [String: [String: RecordsDayStats]] = [:]
        for s in sessions {
            let key = dateKey(for: s.startedAt)
            var modeDays = next[s.mode.rawValue, default: [:]]
            var stats = modeDays[key] ?? RecordsDayStats()
            stats.answered += s.answered
            stats.correct += s.correct
            stats.seconds += s.seconds
            modeDays[key] = stats
            next[s.mode.rawValue] = modeDays
        }
        days = next
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
                RecordsStore.shared.startSession(mode: mode)
                RecordsSessionClock.starts[mode.rawValue] = CACurrentMediaTime()
            }
            .onDisappear {
                let now = CACurrentMediaTime()
                let start = RecordsSessionClock.starts[mode.rawValue] ?? now
                RecordsSessionClock.starts[mode.rawValue] = nil
                let seconds = max(0, Int((now - start).rounded()))
                RecordsStore.shared.addSeconds(mode: mode, seconds: seconds)
                RecordsStore.shared.endSession(mode: mode)
            }
    }
}

extension View {
    func recordSession(mode: TrainingModeRecord) -> some View {
        modifier(RecordsSessionModifier(mode: mode))
    }
}
