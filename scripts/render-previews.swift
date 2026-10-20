import AppKit
import CompanionCore
import ImageIO
import UniformTypeIdentifiers

// A local UI-rendering harness. It draws only our own view and bundled assets;
// it does not capture the screen or inspect another application's window.
extension Bundle {
    static var module: Bundle {
        Bundle(path: CommandLine.arguments[1])!
    }
}

@main struct RenderPreviews {
    static func main() throws {
        _ = NSApplication.shared
        let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        // Exercise the real rendering state, without injecting any system events.
        let scene = KeyboardScene(); scene.reduceMotion = true
        scene.input(code: 0, down: true)
        scene.input(code: 1, down: true)
        scene.input(code: 1, down: true)
        precondition(scene.activeKeys == [0,1])
        precondition(scene.pawTargets().0 == scene.center(scene.keys.first { $0.code == 1 }!))
        scene.input(code: 0, down: false)
        precondition(scene.activeKeys == [1])
        scene.input(code: 35, down: true)
        precondition(scene.pawTargets().1 == scene.center(scene.keys.first { $0.code == 35 }!))
        scene.clear(); precondition(scene.activeKeys.isEmpty)
        scene.reduceMotion = false
        scene.input(code: 0, down: true)
        precondition(scene.pawPositions().0 == scene.center(scene.keys.first { $0.code == 0 }!))
        scene.input(code: 1, down: true)
        precondition(scene.pawPositions().0 == scene.center(scene.keys.first { $0.code == 1 }!))
        let projected = scene.projectedPawPositions()
        let expected = scene.projection.project(point: scene.center(scene.keys.first { $0.code == 1 }!))
        precondition(projected.0 == expected)
        scene.clear()
        for character in Character.allCases {
            precondition(character.bodyImage != nil && character.pawImage(left: true) != nil && character.pawImage(left: false) != nil)
        }
        print("Native chord / repeat / paw-target / release / clear assertions passed")
        if CommandLine.arguments.count > 3 && CommandLine.arguments[3] == "--gif" {
            try renderDemo(to: output.appendingPathComponent("typing-demo.gif"))
            return
        }
        let width = CommandLine.arguments.count > 3 ? CGFloat(Double(CommandLine.arguments[3]) ?? 260) : 260
        let counterText = CommandLine.arguments.count > 4 ? CommandLine.arguments[4] : "1.2 kcal est.  ·  12,480 keys"
        let poses = CommandLine.arguments.count > 3 ? [("idle", [UInt16]())] : [("idle", [UInt16]()), ("A", [UInt16(0)]), ("P", [UInt16(35)]), ("space", [UInt16(49)]), ("arrow", [UInt16(124)]), ("shift-A", [UInt16(56),UInt16(0)])]
        for character in Character.allCases {
            for dark in [false, true] {
              for (pose, codes) in poses {
                let view = CompanionView(frame: NSRect(x: 0, y: 0, width: width, height: width))
                view.character = character
                view.reduceMotion = true
                view.counters = counterText
                view.lightText = dark
                for code in codes { view.updateKey(code: code, down: true) }
                let rep = try renderBitmap(view, dark: dark, busy: CommandLine.arguments.count > 5)
                guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("Could not encode render") }
                let name = "\(character.rawValue)-\(dark ? "dark" : "light")-\(pose).png"
                try png.write(to: output.appendingPathComponent(name))
                print(name)
                view.clearKeys()
              }
            }
        }
    }
    private static func renderBitmap(_ view: CompanionView, dark: Bool, busy: Bool = false) throws -> NSBitmapImageRep {
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { fatalError("Could not allocate render") }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let rendered = NSImage(size: view.bounds.size)
        rendered.lockFocus()
        (dark ? NSColor(calibratedWhite: 0.1, alpha: 1) : NSColor(calibratedWhite: 0.92, alpha: 1)).setFill()
        view.bounds.fill()
        if busy {
            let colors: [NSColor] = [.white, .black, .systemPink, .systemTeal]
            for index in 0...Int(view.bounds.width / 12) {
                colors[index % colors.count].setFill()
                NSRect(x: CGFloat(index) * 12, y: 0, width: 12, height: view.bounds.height).fill()
            }
        }
        let foreground = NSImage(size: view.bounds.size)
        foreground.addRepresentation(bitmap)
        foreground.draw(in: view.bounds, from: .zero, operation: .sourceOver, fraction: 1)
        rendered.unlockFocus()
        guard let tiff = rendered.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { fatalError("Could not encode render") }
        return rep
    }

    private static func renderDemo(to url: URL) throws {
        let view = CompanionView(frame: NSRect(x: 0, y: 0, width: 260, height: 260))
        view.character = .mochi; view.reduceMotion = true; view.lightText = false
        let codes: [UInt16?] = [nil,0,1,2,3,38,40,37,49,123,124,51,36,nil]
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, codes.count, nil) else { fatalError("Could not create GIF") }
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for (index, code) in codes.enumerated() {
            view.clearKeys()
            if let code { view.updateKey(code: code, down: true) }
            view.counters = "1.2 kcal est.  ·  \((12_480 + min(index, 12)).formatted()) keys"
            let rep = try renderBitmap(view, dark: false)
            guard let frame = rep.cgImage else { fatalError("Could not encode GIF frame") }
            let delay = code == nil ? 0.7 : 0.14
            CGImageDestinationAddImage(destination, frame, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]] as CFDictionary)
        }
        guard CGImageDestinationFinalize(destination) else { fatalError("Could not finalize GIF") }
        view.clearKeys()
        print(url.lastPathComponent)
    }

}
