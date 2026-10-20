import XCTest
@testable import CompanionCore

final class KeyboardModelTests: XCTestCase {
    func testPhysicalMappingAndHandAssignment() throws {
        let keys = MacKeyboard.keys()
        let a = try XCTUnwrap(keys.first { $0.code == 0 })
        let s = try XCTUnwrap(keys.first { $0.code == 1 })
        let p = try XCTUnwrap(keys.first { $0.code == 35 })
        XCTAssertEqual(a.label, "A"); XCTAssertLessThan(a.column, s.column)
        XCTAssertFalse(a.rightHand); XCTAssertTrue(p.rightHand)
        for code: UInt16 in [53, 51, 49, 36, 123, 124, 125, 126] { XCTAssertTrue(keys.contains { $0.code == code }) }
    }
    func testHeldChordReleaseAndRepeat() {
        let supported = Set(MacKeyboard.keys().map(\.code))
        var state = HeldKeyboard()
        state.update(code: 0, down: true, supported: supported)
        state.update(code: 1, down: true, supported: supported)
        state.update(code: 1, down: true, supported: supported)
        XCTAssertEqual(state.order, [0,1])
        state.update(code: 0, down: false, supported: supported)
        XCTAssertEqual(state.held, [1])
        state.update(code: 999, down: true, supported: supported)
        XCTAssertEqual(state.held, [1])
        state.clear(); XCTAssertTrue(state.held.isEmpty)
    }
    func testIndependentModifierSides() {
        let supported = Set(MacKeyboard.keys().map(\.code))
        var state = HeldKeyboard()
        for code: UInt16 in [56,60,0] { state.update(code: code, down: true, supported: supported) }
        state.update(code: 56, down: false, supported: supported)
        XCTAssertEqual(state.held, [60,0])
    }
    func testUniqueKeyGeometry() {
            let keys = MacKeyboard.keys()
            XCTAssertEqual(keys.count, Set(keys.map(\.code)).count)
            for key in keys {
                XCTAssertGreaterThan(key.width, 0); XCTAssertGreaterThan(key.height, 0)
                XCTAssertGreaterThanOrEqual(key.column, 0); XCTAssertLessThanOrEqual(key.column + key.width, 15)
            }
    }
}
