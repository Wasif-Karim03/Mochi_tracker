import AppKit
import Carbon
import CompanionCore

/// A listen-only tap. Key positions are forwarded transiently for animation;
/// events are never translated into text, logged or persisted.
final class KeyMonitor {
    private var port: CFMachPort?
    private var source: CFRunLoopSource?
    private var capsGeneration = 0
    var onPress: (() -> Void)?
    var onKey: ((UInt16, Bool) -> Void)?
    var onGap: (() -> Void)?
    var running: Bool { port != nil && CGEvent.tapIsEnabled(tap: port!) }
    var allowed: Bool { CGPreflightListenEventAccess() }
    var secureInput: Bool { IsSecureEventInputEnabled() }

    func start() {
        guard port == nil, allowed else { return }
        let mask = CGEventMask((1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue))
        port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap,
            options: .listenOnly, eventsOfInterest: mask, callback: { _, type, event, info in
                guard let info else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<KeyMonitor>.fromOpaque(info).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    monitor.capsGeneration += 1
                    monitor.onGap?()
                    if let port = monitor.port, monitor.allowed { CGEvent.tapEnable(tap: port, enable: true) }
                } else if monitor.secureInput {
                    monitor.capsGeneration += 1
                    monitor.onGap?()
                } else if type == .keyDown || type == .keyUp {
                    let code = UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
                    monitor.onKey?(code, type == .keyDown)
                    if type == .keyDown && event.getIntegerValueField(.keyboardEventAutorepeat) == 0 { monitor.onPress?() }
                } else if type == .flagsChanged {
                    // Query each physical side instead of using aggregate Shift/Option flags.
                    for code in MacKeyboard.modifiers where code != 57 {
                        monitor.onKey?(code, CGEventSource.keyState(.combinedSessionState, key: code))
                    }
                    if event.getIntegerValueField(.keyboardEventKeycode) == 57 {
                        monitor.capsGeneration += 1
                        let generation = monitor.capsGeneration
                        monitor.onKey?(57, true)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak monitor] in
                            guard let monitor, monitor.capsGeneration == generation else { return }
                            monitor.onKey?(57, false)
                        }
                    }
                }
                return Unmanaged.passUnretained(event)
            }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        if let port {
            source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            CGEvent.tapEnable(tap: port, enable: true)
        }
    }
    func stop() {
        capsGeneration += 1
        if let port { CGEvent.tapEnable(tap: port, enable: false); CFMachPortInvalidate(port) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        port = nil; source = nil; onGap?()
    }
    deinit { stop() }
}
