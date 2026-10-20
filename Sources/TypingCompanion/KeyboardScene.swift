import AppKit
import QuartzCore
import CompanionCore

/// Ephemeral animation state only. Nothing in this class is encoded or logged.
final class KeyboardScene {
    let keys = MacKeyboard.keys()
    private var held = HeldKeyboard()
    private var visibleOrder: [UInt16] = []
    private var minimumUntil: [UInt16: Double] = [:]
    private var lastDown = -100.0
    private var left = PawMotion(home: CGPoint(x: 49, y: 179))
    private var right = PawMotion(home: CGPoint(x: 206, y: 177))
    private var supported: Set<UInt16> { Set(keys.map(\.code)) }
    var activeKeys: Set<UInt16> { held.held }
    var onNeedsDisplay: (() -> Void)?
    private var timer: Timer?
    var reduceMotion = false
    var projection: KeyboardProjection { KeyboardProjection(referenceStyle: true, frontal: character == .keycat || character == .sparkKeycat) }
    private var leftImage = Character.mochi.pawImage(left: true)
    private var rightImage = Character.mochi.pawImage(left: false)
    var character: Character = .mochi {
        didSet {
            leftImage = character.pawImage(left: true); rightImage = character.pawImage(left: false)
            let cat = character == .keycat || character == .sparkKeycat
            left = PawMotion(home: cat ? CGPoint(x: 80, y: 155) : character == .pipBot ? CGPoint(x: 80, y: 193) : CGPoint(x: 49, y: 179))
            right = PawMotion(home: cat ? CGPoint(x: 202, y: 194) : CGPoint(x: 206, y: 177))
            clear()
        }
    }

    func input(code: UInt16, down: Bool, now: Double = CACurrentMediaTime()) {
        guard supported.contains(code) else { return }
        let wasDown = held.held.contains(code)
        held.update(code: code, down: down, supported: supported)
        if down && !wasDown {
            visibleOrder.removeAll { $0 == code }; visibleOrder.append(code)
            minimumUntil[code] = now + 0.10; lastDown = now
        }
        updateTargets(now: now)
        // Key-down contact is immediate, even during fast same-hand typing.
        // Only the release/rest motion is interpolated; do not trail a live key.
        if down && !wasDown, let key = keys.first(where: { $0.code == code }) {
            if key.rightHand { right.move(to: center(key), now: now, instant: true) }
            else { left.move(to: center(key), now: now, instant: true) }
        }
        onNeedsDisplay?(); startTimer()
    }
    func clear() {
        held.clear(); visibleOrder.removeAll(); minimumUntil.removeAll(); lastDown = -100
        left.reset(); right.reset(); timer?.invalidate(); timer = nil; onNeedsDisplay?()
    }
    private var reduced: Bool { reduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    private func startTimer() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            let now = CACurrentMediaTime()
            self.updateTargets(now: now); self.onNeedsDisplay?()
            let linger = self.minimumUntil.values.contains { $0 > now }
            if !linger && !self.left.moving(now: now) && !self.right.moving(now: now) {
                self.timer?.invalidate(); self.timer = nil
            }
        }
        self.timer = timer; RunLoop.main.add(timer, forMode: .common)
    }
    private func updateTargets(now: Double) {
        visibleOrder.removeAll { !held.held.contains($0) && (minimumUntil[$0] ?? 0) <= now }
        minimumUntil = minimumUntil.filter { visibleOrder.contains($0.key) }
        let active = visibleOrder.compactMap { code in keys.first { $0.code == code } }
        let l = active.last { !$0.rightHand }
        let r = active.last { $0.rightHand }
        left.move(to: l.map { center($0) } ?? left.home, now: now, instant: reduced)
        right.move(to: r.map { center($0) } ?? right.home, now: now, instant: reduced)
    }
    func rect(_ key: PhysicalKey) -> CGRect {
        CGRect(x: 13 + key.column * 15.6, y: 169 + key.row * 10.3,
               width: key.width * 15.6 - 1.35, height: key.height * 10.3 - 1.25)
    }
    func center(_ key: PhysicalKey) -> CGPoint { let r = rect(key); return CGPoint(x: r.midX, y: r.midY) }
    func pawTargets() -> (CGPoint, CGPoint) { (left.target, right.target) }
    func pawPositions(now: Double = CACurrentMediaTime()) -> (CGPoint, CGPoint) {
        (left.position(now: now), right.position(now: now))
    }

    func projectedPawPositions(now: Double = CACurrentMediaTime()) -> (CGPoint, CGPoint) {
        let positions = pawPositions(now: now)
        return (projection.project(point: positions.0), projection.project(point: positions.1))
    }
    func drawKeyboard(context: CGContext, now: Double) {
        context.saveGState()
        context.concatenate(projection.transform)
        defer { context.restoreGState() }
        let purple = character == .mochi
        let mint = character == .pipBot
        let base = purple ? NSColor(calibratedRed: 0.74, green: 0.59, blue: 0.86, alpha: 1)
            : NSColor(calibratedRed: 0.88, green: 0.78, blue: 0.64, alpha: 1)
        let body = NSBezierPath(roundedRect: CGRect(x: 7, y: 176, width: 246, height: 70), xRadius: 12, yRadius: 12)
        NSGradient(starting: base.blended(withFraction: 0.28, of: .white)!, ending: base.blended(withFraction: 0.15, of: .black)!)!.draw(in: body, angle: 90)
        let top = NSBezierPath(roundedRect: CGRect(x: 7, y: 161, width: 246, height: 70), xRadius: 12, yRadius: 12)
        NSGradient(starting: base.blended(withFraction: 0.48, of: .white)!, ending: base)!.draw(in: top, angle: 90)
        for key in keys {
            let pressed = held.held.contains(key.code) || (minimumUntil[key.code] ?? 0) > now
            var r = rect(key)
            base.blended(withFraction: 0.08, of: .black)!.setFill()
            NSBezierPath(roundedRect: r.offsetBy(dx: 0, dy: 5), xRadius: 3.4, yRadius: 3.4).fill()
            if pressed { r.origin.y += 1.4 }
            let accented = [UInt16(53),48,56,59,58,55,123,124,125,126].contains(key.code)
            let normal = purple ? base.blended(withFraction: 0.45, of: .white)!
                : mint ? (accented ? NSColor(calibratedRed: 0.39, green: 0.72, blue: 0.54, alpha: 1) : NSColor(calibratedRed: 0.74, green: 0.86, blue: 0.74, alpha: 1))
                : (accented ? NSColor(calibratedRed: 0.97, green: 0.70, blue: 0.27, alpha: 1) : NSColor(calibratedRed: 0.99, green: 0.93, blue: 0.82, alpha: 1))
            let down = mint ? NSColor(calibratedRed: 0.41, green: 0.96, blue: 0.79, alpha: 1) : purple ? NSColor(calibratedRed: 0.72, green: 0.56, blue: 1, alpha: 1) : NSColor(calibratedRed: 1, green: 0.70, blue: 0.30, alpha: 1)
            let color = pressed ? down : normal
            NSGradient(starting: color.blended(withFraction: 0.4, of: .white)!, ending: color)!.draw(in: NSBezierPath(roundedRect: r, xRadius: 3.4, yRadius: 3.4), angle: 90)
            if pressed {
                down.blended(withFraction: 0.35, of: .black)!.setStroke()
                let stroke = NSBezierPath(roundedRect: r, xRadius: 3.4, yRadius: 3.4); stroke.lineWidth = 0.8; stroke.stroke()
            }

        }
        if character == .keycat || character == .sparkKeycat {
            context.setFillColor(NSColor(calibratedRed: 0.48, green: 0.27, blue: 0.14, alpha: 0.85).cgColor)
            context.fillEllipse(in: CGRect(x: 235.3, y: 238, width: 5.2, height: 4.0))
            for (x, y) in [(234.1,236.1),(236.3,234.8),(239.0,234.8),(241.0,236.1)] {
                context.fillEllipse(in: CGRect(x: x, y: y, width: 1.8, height: 2.0))
            }
        }

    }
    func drawPaws(context: CGContext, now: Double) {
        let positions = projectedPawPositions(now: now)
        for (paw, image) in [(positions.0, leftImage), (positions.1, rightImage)] {
            // Fingertips land on the projected key center. A full, short wrist
            // is part of the sprite; there are no stretched shoulder connectors.
            let width: CGFloat = character == .mochi ? 43 : 35
            let height = image.map { width * $0.size.height / $0.size.width } ?? 28
            let r = CGRect(x: paw.x - width / 2, y: paw.y - height + 0.8, width: width, height: height)
            context.saveGState()
            let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.20)
            shadow.shadowBlurRadius = 1.8; shadow.shadowOffset = CGSize(width: 0, height: -0.7)
            shadow.set()
            image?.draw(in: r, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true,
                        hints: [.interpolation: NSImageInterpolation.high])
            context.restoreGState()
        }
    }
    deinit { timer?.invalidate() }
}

private struct PawMotion {
    let home: CGPoint
    var start: CGPoint
    var target: CGPoint
    var began = -100.0
    var duration = 0.065
    init(home: CGPoint) { self.home = home; start = home; target = home }
    func position(now: Double) -> CGPoint {
        let t = min(1, max(0, (now - began) / duration))
        let eased = 1 - pow(1 - t, 3)
        return CGPoint(x: start.x + (target.x - start.x) * eased, y: start.y + (target.y - start.y) * eased)
    }
    mutating func move(to point: CGPoint, now: Double, instant: Bool) {
        guard point != target else { if instant { start = target; began = now - duration }; return }
        start = position(now: now); target = point; began = instant ? now - duration : now
    }
    func moving(now: Double) -> Bool { now < began + duration }
    mutating func reset() { start = home; target = home; began = -100 }
}
