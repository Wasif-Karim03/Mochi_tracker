import CoreGraphics
import XCTest
@testable import CompanionCore

final class KeyboardProjectionTests: XCTestCase {
    private let projection = KeyboardProjection()

    func testKnownAKeyCenterProjection() throws {
        let key = try XCTUnwrap(MacKeyboard.keys().first { $0.code == 0 })
        let rect = sourceRect(for: key)
        let projected = projection.project(point: CGPoint(x: rect.midX, y: rect.midY))

        XCTAssertEqual(projected.x, 70.50105, accuracy: 0.000_001)
        XCTAssertEqual(projected.y, 202.80585, accuracy: 0.000_001)
    }

    func testInverseProjectionRoundTripsPoints() {
        let points = [
            CGPoint(x: 130, y: 198),
            CGPoint(x: 7, y: 161),
            CGPoint(x: 253, y: 234),
            CGPoint(x: 47.425, y: 202.88),
        ]

        for point in points {
            let roundTrip = projection.unproject(point: projection.project(point: point))
            XCTAssertEqual(roundTrip.x, point.x, accuracy: 0.000_001)
            XCTAssertEqual(roundTrip.y, point.y, accuracy: 0.000_001)
        }
    }

    func testProjectedBoardHasExpectedCompactBounds() {
        let corners = projection.project(rect: KeyboardProjection.sourceBoardBounds)
        let bounds = boundingRect(of: corners)

        XCTAssertEqual(corners[0].x, 34.29, accuracy: 0.000_001)
        XCTAssertEqual(corners[0].y, 179.67, accuracy: 0.000_001)
        XCTAssertEqual(bounds.width, 191.26, accuracy: 0.000_001)
        XCTAssertEqual(bounds.height, 62.48, accuracy: 0.000_001)
    }

    func testEveryKeyCornerStaysInsideProjectedBoard() {
        let board = projection.project(rect: KeyboardProjection.sourceBoardBounds)

        for key in MacKeyboard.keys() {
            for corner in projection.project(rect: sourceRect(for: key)) {
                XCTAssertTrue(
                    contains(corner, inConvexPolygon: board),
                    "Key \(key.label) corner \(corner) escaped the projected board"
                )
            }
        }
    }

    func testReferenceStyleProjectsEveryMacKeyWithInvertibleMapping() {
        for frontal in [false, true] {
            let reference = KeyboardProjection(referenceStyle: true, frontal: frontal)
            let board = reference.project(rect: CGRect(x: 7, y: 161, width: 246, height: 85))
            for key in MacKeyboard.keys() {
                let rect = sourceRect(for: key)
                let point = CGPoint(x: rect.midX, y: rect.midY)
                let screen = reference.project(point: point)
                XCTAssertTrue(contains(screen, inConvexPolygon: board))
                let restored = reference.unproject(point: screen)
                XCTAssertEqual(restored.x, point.x, accuracy: 0.000_001)
                XCTAssertEqual(restored.y, point.y, accuracy: 0.000_001)
            }
        }
    }

    private func sourceRect(for key: PhysicalKey) -> CGRect {
        CGRect(
            x: 13 + key.column * 15.6,
            y: 169 + key.row * 10.3,
            width: key.width * 15.6 - 1.35,
            height: key.height * 10.3 - 1.25
        )
    }

    private func boundingRect(of points: [CGPoint]) -> CGRect {
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        return CGRect(
            x: xs.min()!,
            y: ys.min()!,
            width: xs.max()! - xs.min()!,
            height: ys.max()! - ys.min()!
        )
    }

    private func contains(_ point: CGPoint, inConvexPolygon polygon: [CGPoint]) -> Bool {
        var sign: CGFloat?
        for index in polygon.indices {
            let start = polygon[index]
            let end = polygon[(index + 1) % polygon.count]
            let cross = (end.x - start.x) * (point.y - start.y)
                - (end.y - start.y) * (point.x - start.x)
            if abs(cross) < 0.000_001 { continue }
            if let sign {
                if cross * sign < 0 { return false }
            } else {
                sign = cross
            }
        }
        return true
    }
}
