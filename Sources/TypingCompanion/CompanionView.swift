import AppKit
import ImageIO
import QuartzCore

enum Character: String, CaseIterable {
    case mochi = "Mochi", keycat = "Keycat", pipBot = "Pip Bot", sparkKeycat = "Spark Keycat"
    var image: NSImage? {
        guard let url = Bundle.module.url(forResource: rawValue, withExtension: "png", subdirectory: "Resources") else { return nil }
        return NSImage(contentsOf: url)
    }
    private func sprite(_ part: Int) -> NSImage? {
        guard let url = Bundle.module.url(forResource: rawValue + " Reference Rig", withExtension: "png", subdirectory: "Resources"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let atlas = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        // Atlas regions include a little transparent padding; body silhouettes
        // may extend past the nominal quadrant. No texture is decoded per frame.
        let split: CGFloat = self == .pipBot ? 0.65 : self == .sparkKeycat ? 0.755 : 0.72
        let pawStart: CGFloat = self == .pipBot ? 0.67 : self == .sparkKeycat ? 0.755 : 0.725
        let regions = [CGRect(x: 0, y: 0, width: split, height: 1),
                       CGRect(x: pawStart, y: 0, width: 1 - pawStart, height: 0.5),
                       CGRect(x: pawStart, y: 0.52, width: 1 - pawStart, height: 0.48)]
        let r = regions[part]
        guard let cropped = atlas.cropping(to: CGRect(x: r.minX * CGFloat(atlas.width), y: r.minY * CGFloat(atlas.height),
            width: r.width * CGFloat(atlas.width), height: r.height * CGFloat(atlas.height))) else { return nil }
        let sprite = Self.trimTransparentPadding(cropped)
        return NSImage(cgImage: sprite, size: NSSize(width: sprite.width, height: sprite.height))
    }
    private static func trimTransparentPadding(_ image: CGImage) -> CGImage {
        // Normalize sprite padding once at load time, so every character's
        // lowest fingertip has the same contact anchor on the keyboard.
        let w = image.width, h = image.height
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        var minX = w, minY = h, maxX = -1, maxY = -1
        let rendered = bytes.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(data: raw.baseAddress, width: w, height: h,
                bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard rendered else { return image }
        for y in 0..<h {
            for x in 0..<w where bytes[(y * w + x) * 4 + 3] > 24 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return image }
        return image.cropping(to: CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)) ?? image
    }
    var bodyImage: NSImage? {
        if let image = sprite(0) { return image }
        guard let url = Bundle.module.url(forResource: rawValue + " Body", withExtension: "png", subdirectory: "Resources") else { return nil }
        return NSImage(contentsOf: url)
    }
    func pawImage(left: Bool) -> NSImage? { sprite(left ? 1 : 2) }

}

/// Reads only the configured wallpaper image. Never captures the display or other apps.
final class WallpaperContrast {
    private var cachedURL: URL?
    private var cachedAspect: CGFloat?
    private var cachedModificationDate: Date?
    private var pixels: [UInt8] = []
    func lightText(at point: NSPoint, screen: NSScreen) -> Bool {
        let url = NSWorkspace.shared.desktopImageURL(for: screen)
        let aspect = screen.frame.width / screen.frame.height
        let modified = url.flatMap { try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate }
        if url != cachedURL || aspect != cachedAspect || modified != cachedModificationDate || pixels.isEmpty {
            cachedURL = url; cachedAspect = aspect; cachedModificationDate = modified; pixels = []
            if let url, let source = CGImageSourceCreateWithURL(url as CFURL, nil),
               let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                var bytes = [UInt8](repeating: 0, count: 64 * 64 * 4)
                let success = bytes.withUnsafeMutableBytes { raw -> Bool in
                    guard let context = CGContext(data: raw.baseAddress, width: 64, height: 64,
                        bitsPerComponent: 8, bytesPerRow: 64 * 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
                    // Approximate the default aspect-fill wallpaper crop without a screenshot.
                    let screenAspect = screen.frame.width / screen.frame.height
                    let imageAspect = CGFloat(image.width) / CGFloat(image.height)
                    var crop = CGRect(x: 0, y: 0, width: image.width, height: image.height)
                    if imageAspect > screenAspect { crop.size.width = crop.height * screenAspect; crop.origin.x = (CGFloat(image.width) - crop.width) / 2 }
                    else { crop.size.height = crop.width / screenAspect; crop.origin.y = (CGFloat(image.height) - crop.height) / 2 }
                    context.draw(image.cropping(to: crop) ?? image, in: CGRect(x: 0, y: 0, width: 64, height: 64))
                    return true
                }
                if success { pixels = bytes }
            }
        }
        guard !pixels.isEmpty else {
            return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
        let x = min(63, max(0, Int((point.x - screen.frame.minX) / screen.frame.width * 64)))
        // Decoded image row zero is the top; AppKit screen coordinates start at the bottom.
        let y = min(63, max(0, Int((1 - (point.y - screen.frame.minY) / screen.frame.height) * 64)))
        var luminance = 0.0; var samples = 0.0
        for dx in -8...8 {
            let offset = (y * 64 + min(63, max(0, x + dx))) * 4
            let channels = (0..<3).map { Double(pixels[offset + $0]) / 255 }.map { $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
            luminance += channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722
            samples += 1
        }
        let l = luminance / samples
        return 1.05 / (l + 0.05) > (l + 0.05) / 0.05
    }
}

final class CompanionPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class CompanionView: NSView {
    override var isFlipped: Bool { true }
    var character: Character = .mochi { didSet { image = character.bodyImage; keyboard.character = character; previewScene?.character = character; needsDisplay = true } }
    private var image: NSImage? = Character.mochi.bodyImage
    let keyboard = KeyboardScene()
    private var previewScene: KeyboardScene?
    var counters = "— kcal est.  ·  0 keys" { didSet { needsDisplay = true } }
    var lightText = false { didSet { if lightText != oldValue { needsDisplay = true } } }
    var reduceMotion = false { didSet { keyboard.reduceMotion = reduceMotion; previewScene?.reduceMotion = reduceMotion; needsDisplay = true } }
    var showMenu: ((NSEvent) -> Void)?
    var onMoved: (() -> Void)?
    private var dragStart: NSPoint?
    private var windowStart: NSPoint?
    override init(frame: NSRect) {
        super.init(frame: frame)
        keyboard.onNeedsDisplay = { [weak self] in self?.needsDisplay = true }
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel("Typing companion. Right-click for settings. Drag to move.")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    func updateKey(code: UInt16, down: Bool) {
        previewScene?.clear(); previewScene = nil
        keyboard.input(code: code, down: down)
    }
    func clearKeys() {
        previewScene?.clear(); previewScene = nil; keyboard.clear()
    }
    func clearLiveKeys() { keyboard.clear() }
    func previewTyping() {
        previewScene?.clear()
        let demo = KeyboardScene(); demo.character = character; demo.reduceMotion = reduceMotion
        demo.onNeedsDisplay = { [weak self] in self?.needsDisplay = true }; previewScene = demo
        for (i, code) in [0,1,2,3,38,40,37,49,123,124,51,36].map({ UInt16($0) }).enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.17) { [weak self, weak demo] in
                guard let self, let demo, self.previewScene === demo else { return }
                demo.input(code: code, down: true)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.17 + 0.09) { [weak self, weak demo] in
                guard let self, let demo, self.previewScene === demo else { return }
                demo.input(code: code, down: false)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) { [weak self, weak demo] in
            guard let self, let demo, self.previewScene === demo else { return }
            demo.clear(); self.previewScene = nil; self.needsDisplay = true
        }
    }
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let scale = bounds.width / 260
        context.saveGState(); context.scaleBy(x: scale, y: scale)
        drawFooter(counters, context: context)
        let scene = previewScene ?? keyboard
        let now = CACurrentMediaTime()
        let bodyRect: NSRect
        switch character {
        case .mochi: bodyRect = NSRect(x: 39, y: 31, width: 178, height: 116)
        case .keycat: bodyRect = NSRect(x: 25, y: 28, width: 197, height: 142)
        case .pipBot: bodyRect = NSRect(x: 47, y: 13, width: 157, height: 167)
        case .sparkKeycat: bodyRect = NSRect(x: 22, y: 16, width: 199, height: 155)
        }
        image?.draw(in: bodyRect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
        scene.drawKeyboard(context: context, now: now)
        scene.drawPaws(context: context, now: now)
        context.restoreGState()
    }
    private func drawFooter(_ text: String, context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        if character == .keycat || character == .sparkKeycat { context.translateBy(x: -14, y: 0) }
        let parts = text.components(separatedBy: "·").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2 else { return }
        let values = [parts[0].replacingOccurrences(of: " kcal est.", with: ""),
                      parts[1].replacingOccurrences(of: " keys", with: "")]
        let rect = CGRect(x: 46, y: 203, width: 196, height: 46)
        // A small solid instrument face. Paired foreground/surface colors
        // retain contrast even when an app window covers the wallpaper.
        let top = lightText ? NSColor(calibratedRed: 0.28, green: 0.28, blue: 0.27, alpha: 1)
                            : NSColor(calibratedRed: 0.98, green: 0.97, blue: 0.93, alpha: 1)
        let bottom = lightText ? NSColor(calibratedRed: 0.21, green: 0.21, blue: 0.20, alpha: 1)
                               : NSColor(calibratedRed: 0.91, green: 0.90, blue: 0.86, alpha: 1)
        let edge = lightText ? NSColor(calibratedWhite: 0.12, alpha: 1)
                             : NSColor(calibratedRed: 0.64, green: 0.63, blue: 0.59, alpha: 1)
        let foreground = lightText ? NSColor(calibratedRed: 0.97, green: 0.96, blue: 0.91, alpha: 1)
                                   : NSColor(calibratedRed: 0.18, green: 0.19, blue: 0.18, alpha: 1)
        let secondary = lightText ? NSColor(calibratedRed: 0.80, green: 0.79, blue: 0.74, alpha: 1)
                                  : NSColor(calibratedRed: 0.37, green: 0.38, blue: 0.35, alpha: 1)
        let face = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: 1.5), blur: 2.5,
                          color: NSColor.black.withAlphaComponent(0.20).cgColor)
        edge.setFill()
        NSBezierPath(roundedRect: rect.offsetBy(dx: 0, dy: 2), xRadius: 8, yRadius: 8).fill()
        context.restoreGState()
        NSGradient(starting: top, ending: bottom)!.draw(in: face, angle: -90)
        edge.withAlphaComponent(0.85).setStroke(); face.lineWidth = 0.65; face.stroke()
        let rim = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: 7, yRadius: 7)
        NSColor.white.withAlphaComponent(lightText ? 0.15 : 0.85).setStroke()
        rim.lineWidth = 0.5; rim.stroke()
        // Adjacent dark/light hairlines read as a seam cut into the face.
        for (x, color) in [(CGFloat(144), NSColor.black.withAlphaComponent(lightText ? 0.35 : 0.16)),
                           (CGFloat(144.7), NSColor.white.withAlphaComponent(lightText ? 0.10 : 0.75))] {
            color.setStroke()
            let seam = NSBezierPath(); seam.move(to: CGPoint(x: x, y: 212)); seam.line(to: CGPoint(x: x, y: 240))
            seam.lineWidth = 0.65; seam.stroke()
        }
        for index in 0..<2 {
            let center: CGFloat = index == 0 ? 95 : 193
            var size: CGFloat = 19
            var attributes: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: size, weight: .medium), .foregroundColor: foreground]
            let value = values[index] as NSString
            while value.size(withAttributes: attributes).width > 86 && size > 11 {
                size -= 0.5; attributes[.font] = NSFont.monospacedDigitSystemFont(ofSize: size, weight: .medium)
            }
            let valueSize = value.size(withAttributes: attributes)
            let origin = CGPoint(x: center - valueSize.width / 2, y: 206 + (19 - size) / 2)
            var relief = attributes
            relief[.foregroundColor] = lightText ? NSColor.black.withAlphaComponent(0.4) : NSColor.white.withAlphaComponent(0.8)
            value.draw(at: CGPoint(x: origin.x, y: origin.y + 0.5), withAttributes: relief)
            value.draw(at: origin, withAttributes: attributes)
            let label = index == 0 ? "kcal est." : "keys"
            let labelAttributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12.5, weight: .regular), .foregroundColor: secondary]
            let labelSize = (label as NSString).size(withAttributes: labelAttributes)
            let iconWidth: CGFloat = index == 0 ? 11 : 15
            let start = center - (iconWidth + 4 + labelSize.width) / 2
            let accent = lightText ? NSColor(calibratedRed: 0.80, green: 0.75, blue: 0.62, alpha: 1)
                                   : NSColor(calibratedRed: 0.48, green: 0.42, blue: 0.31, alpha: 1)
            let symbol = NSImage(systemSymbolName: index == 0 ? "flame" : "keyboard", accessibilityDescription: nil)?
                .withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [accent]))
            symbol?.draw(in: CGRect(x: start, y: 229, width: iconWidth, height: index == 0 ? 13 : 10), from: .zero,
                operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            (label as NSString).draw(at: CGPoint(x: start + iconWidth + 4, y: 226), withAttributes: labelAttributes)
        }
    }
    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) { showMenu?(event); return }
        dragStart = NSEvent.mouseLocation; windowStart = window?.frame.origin
    }
    override func mouseDragged(with event: NSEvent) {
        guard let dragStart, let windowStart else { return }
        let current = NSEvent.mouseLocation
        window?.setFrameOrigin(NSPoint(x: windowStart.x + current.x - dragStart.x, y: windowStart.y + current.y - dragStart.y))
        onMoved?()
    }
    override func mouseUp(with event: NSEvent) { dragStart = nil; windowStart = nil; onMoved?() }
    override func rightMouseDown(with event: NSEvent) { showMenu?(event) }
}
