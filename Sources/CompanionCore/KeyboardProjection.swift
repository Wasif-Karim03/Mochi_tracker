import CoreGraphics
import Foundation

/// Shared projection from the keyboard's source canvas into its compact,
/// three-quarter presentation. Keycaps and paw targets must use this same map.
public struct KeyboardProjection {
    /// Bounds covering the keyboard top and its lower body edge in source space.
    public static let sourceBoardBounds = CGRect(x: 7, y: 161, width: 246, height: 73)

    public let transform: CGAffineTransform

    public init(referenceStyle: Bool = false, frontal: Bool = false) {
        if frontal {
            transform = CGAffineTransform(a: 0.73, b: 0, c: 0.10, d: 0.43, tx: 15.3, ty: 92.86)
            return
        }
        if referenceStyle {
            transform = CGAffineTransform(a: 0.68, b: -0.055, c: 0.17, d: 0.42, tx: 22.94, ty: 90.99)
            return
        }
        // x' = 130 + 0.73(x - 130) + 0.16(y - 198)
        // y' = 194 - 0.07(x - 130) + 0.62(y - 198)
        transform = CGAffineTransform(
            a: 0.73,
            b: -0.07,
            c: 0.16,
            d: 0.62,
            tx: 3.42,
            ty: 80.34
        )
    }

    public func project(point: CGPoint) -> CGPoint {
        point.applying(transform)
    }

    /// Returns the transformed corners in clockwise source-space order:
    /// minimum/minimum, maximum/minimum, maximum/maximum, minimum/maximum.
    public func project(rect: CGRect) -> [CGPoint] {
        [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.maxY),
        ].map(project(point:))
    }

    public func unproject(point: CGPoint) -> CGPoint {
        point.applying(transform.inverted())
    }
}
