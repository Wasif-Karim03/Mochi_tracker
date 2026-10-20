import XCTest
@testable import CompanionCore

final class TypingLedgerTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    func testRepeatsAndIdleDoNotInflateTotals() {
        var ledger = TypingLedger(now: now)
        ledger.record(now: now, uptime: 10)
        ledger.record(now: now, uptime: 11, isRepeat: true)
        ledger.record(now: now, uptime: 12)
        ledger.record(now: now, uptime: 100)
        XCTAssertEqual(ledger.totals.keys, 3)
        XCTAssertEqual(ledger.totals.activeSeconds, 2)
    }
    func testPauseAndRestartDoNotCreditGaps() {
        var ledger = TypingLedger(now: now)
        ledger.record(now: now, uptime: 1)
        ledger.breakSession()
        ledger.record(now: now, uptime: 3)
        var restored = TypingLedger(totals: ledger.totals, now: now)
        restored.record(now: now, uptime: 4)
        XCTAssertEqual(restored.totals.keys, 3)
        XCTAssertEqual(restored.totals.activeSeconds, 0)
    }
    func testMidnightAndTimeZoneRollover() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = cal.startOfDay(for: now)
        var ledger = TypingLedger(now: day, calendar: cal)
        ledger.record(now: day.addingTimeInterval(86399), uptime: 10, calendar: cal)
        ledger.record(now: day.addingTimeInterval(86401), uptime: 12, calendar: cal)
        XCTAssertEqual(ledger.totals.keys, 1)
        XCTAssertEqual(ledger.totals.activeSeconds, 0)
        cal.timeZone = TimeZone(secondsFromGMT: -3600)!
        XCTAssertTrue(ledger.refreshDay(now: day.addingTimeInterval(86401), calendar: cal))
    }
    func testEstimateRequiresValidWeightAndUsesNetMET() throws {
        let totals = DayTotals(day: TypingLedger.dayKey(now), keys: 100, activeSeconds: 3600)
        let ledger = TypingLedger(totals: totals, now: now)
        XCTAssertNil(ledger.estimatedExtraCalories(weightKG: nil))
        XCTAssertNil(ledger.estimatedExtraCalories(weightKG: .nan))
        XCTAssertNil(ledger.estimatedExtraCalories(weightKG: 0))
        XCTAssertEqual(try XCTUnwrap(ledger.estimatedExtraCalories(weightKG: 70)), 21, accuracy: 0.0001)
    }
    func testPersistenceAndCorruptData() throws {
        let totals = DayTotals(day: TypingLedger.dayKey(now), keys: 42, activeSeconds: 3)
        let decoded = try JSONDecoder().decode(DayTotals.self, from: JSONEncoder().encode(totals))
        XCTAssertEqual(TypingLedger(totals: decoded, now: now).totals, totals)
        let corrupt = DayTotals(day: totals.day, keys: -1, activeSeconds: -2)
        XCTAssertEqual(TypingLedger(totals: corrupt, now: now).totals.keys, 0)
    }
    func testNegativeUptimeDeltaIsNotCredited() {
        var ledger = TypingLedger(now: now)
        ledger.record(now: now, uptime: 20)
        ledger.record(now: now, uptime: 19)
        XCTAssertEqual(ledger.totals.activeSeconds, 0)
    }
}
