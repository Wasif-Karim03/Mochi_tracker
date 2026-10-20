import Foundation

public struct DayTotals: Codable, Equatable {
    public var day: String
    public var keys: Int
    public var activeSeconds: Double
    public init(day: String, keys: Int = 0, activeSeconds: Double = 0) {
        self.day = day; self.keys = keys; self.activeSeconds = activeSeconds
    }
}

/// Aggregates only. No typed characters, key codes, application names or event history.
public struct TypingLedger {
    public private(set) var totals: DayTotals
    private var lastUptime: TimeInterval?
    public init(totals: DayTotals? = nil, now: Date = Date(), calendar: Calendar = .current) {
        let day = Self.dayKey(now, calendar: calendar)
        if let totals, totals.day == day, totals.keys >= 0,
           totals.activeSeconds.isFinite, totals.activeSeconds >= 0 {
            self.totals = totals
        } else { self.totals = DayTotals(day: day) }
    }
    public static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.era, .year, .month, .day], from: date)
        return "\(c.era ?? 1)-\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }
    @discardableResult public mutating func refreshDay(now: Date, calendar: Calendar = .current) -> Bool {
        let day = Self.dayKey(now, calendar: calendar)
        guard totals.day != day else { return false }
        totals = DayTotals(day: day); lastUptime = nil; return true
    }
    public mutating func breakSession() { lastUptime = nil }
    public mutating func record(now: Date, uptime: TimeInterval, isRepeat: Bool = false, calendar: Calendar = .current) {
        refreshDay(now: now, calendar: calendar)
        guard !isRepeat, uptime.isFinite else { return }
        totals.keys += 1
        // Count only intervals bounded by two key presses at most five seconds apart.
        // Never credit an idle tail or restore a session across app launches.
        if let lastUptime {
            let elapsed = uptime - lastUptime
            if elapsed >= 0 && elapsed <= 5 { totals.activeSeconds += elapsed }
        }
        lastUptime = uptime
    }
    public func estimatedExtraCalories(weightKG: Double?) -> Double? {
        guard let weightKG, weightKG.isFinite, (20...350).contains(weightKG) else { return nil }
        return 0.3 * weightKG * totals.activeSeconds / 3600
    }
}
