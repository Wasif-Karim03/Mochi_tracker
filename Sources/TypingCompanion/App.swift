import AppKit
import CompanionCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSTextFieldDelegate {
    private let defaults = UserDefaults.standard
    private let monitor = KeyMonitor()
    private let contrast = WallpaperContrast()
    private var ledger = TypingLedger()
    private var panel: CompanionPanel!
    private var companion: CompanionView!
    private var statusItem: NSStatusItem!
    private var menu = NSMenu()
    private var settings: NSWindow?
    private var statusLabel: NSTextField?
    private var weightField: NSTextField?
    private var characterPopup: NSPopUpButton?
    private var textPopup: NSPopUpButton?
    private var motionCheck: NSButton?
    private var sizeSlider: NSSlider?
    private var tick: Timer?
    private var saveTick = 0
    private var weight: Double? { let n = defaults.double(forKey: "weightKG"); return (20...350).contains(n) ? n : nil }
    private var paused: Bool { defaults.bool(forKey: "paused") }
    private var statusText: String {
        if paused { return "Paused — no typing is counted" }
        if !monitor.allowed { return "Input Monitoring permission needed" }
        if monitor.secureInput { return "Secure Input is active — counting is suspended" }
        if !monitor.running { return "Keyboard listener unavailable — try reconnecting" }
        return "Counting locally · \(ledger.totals.keys.formatted()) keys today"
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let data = defaults.data(forKey: "dailyTotals"), let stored = try? JSONDecoder().decode(DayTotals.self, from: data) {
            ledger = TypingLedger(totals: stored)
        }
        NSApp.setActivationPolicy(.accessory)
        companion = CompanionView(frame: NSRect(x: 0, y: 0, width: 260, height: 260))
        companion.character = Character(rawValue: defaults.string(forKey: "character") ?? "") ?? .mochi
        companion.reduceMotion = defaults.bool(forKey: "reduceMotion")
        panel = CompanionPanel(contentRect: companion.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "Typing Companion"
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.level = .floating; panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = companion; panel.isReleasedWhenClosed = false
        companion.showMenu = { [weak self] event in
            guard let self else { return }; self.populateMenu(); NSMenu.popUpContextMenu(self.menu, with: event, for: self.companion)
        }
        companion.onMoved = { [weak self] in self?.savePosition(); self?.updateContrast() }
        resizePanel()
        if defaults.object(forKey: "positionX") != nil {
            panel.setFrameOrigin(NSPoint(x: defaults.double(forKey: "positionX"), y: defaults.double(forKey: "positionY")))
        } else { placeAtCorner() }
        keepOnScreen()
        panel.orderFrontRegardless()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Typing Companion")
        menu.delegate = self; statusItem.menu = menu
        monitor.onPress = { [weak self] in
            guard let self, !self.paused else { return }
            self.ledger.record(now: Date(), uptime: ProcessInfo.processInfo.systemUptime)
            self.updateCounters()
        }
        monitor.onKey = { [weak self] code, down in
            guard let self, !self.paused else { return }
            self.companion.updateKey(code: code, down: down)
        }
        monitor.onGap = { [weak self] in self?.ledger.breakSession(); self?.companion.clearLiveKeys() }
        updateMonitoring(); updateCounters(); updateContrast()
        tick = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.heartbeat() }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(sleeping), name: NSWorkspace.willSleepNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development"
        if !defaults.bool(forKey: "hasLaunched") || !monitor.allowed || defaults.string(forKey: "lastSeenVersion") != version {
            defaults.set(true, forKey: "hasLaunched"); defaults.set(version, forKey: "lastSeenVersion"); openSettings(nil)
        }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        panel.orderFrontRegardless(); openSettings(nil); return true
    }
    func applicationWillTerminate(_ notification: Notification) { save(); monitor.stop(); tick?.invalidate() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    @objc private func sleeping() { ledger.breakSession(); companion.clearKeys(); save() }
    @objc private func screenChanged() { keepOnScreen(); updateContrast() }
    private func heartbeat() {
        if ledger.refreshDay(now: Date()) { save(); updateCounters() }
        updateMonitoring()
        if paused || monitor.secureInput || !monitor.running { ledger.breakSession(); companion.clearLiveKeys() }
        statusLabel?.stringValue = statusText
        statusItem.button?.toolTip = "Typing Companion — \(statusText)"
        saveTick += 1
        if saveTick % 5 == 0 { save(); updateContrast() }
    }
    private func updateMonitoring() {
        if paused || !monitor.allowed { if monitor.running { monitor.stop() }; return }
        if !monitor.running { monitor.stop(); monitor.start() }
    }
    private func updateCounters() {
        let calories = ledger.estimatedExtraCalories(weightKG: weight).map { String(format: "%.1f", $0) } ?? "—"
        companion.counters = "\(calories) kcal est.  ·  \(ledger.totals.keys.formatted()) keys"
        companion.setAccessibilityValue("\(ledger.totals.keys) keys today. \(calories) estimated kilocalories above rest.")
    }
    private func save() {
        if let data = try? JSONEncoder().encode(ledger.totals) { defaults.set(data, forKey: "dailyTotals") }
    }
    private func savePosition() {
        defaults.set(panel.frame.minX, forKey: "positionX"); defaults.set(panel.frame.minY, forKey: "positionY")
    }
    private func resizePanel() {
        let stored = defaults.double(forKey: "size")
        let width = stored == 0 ? 240 : min(360, max(180, stored))
        panel.setContentSize(NSSize(width: width, height: width))
        companion.frame = NSRect(origin: .zero, size: panel.contentLayoutRect.size)
    }
    private func keepOnScreen() {
        let screens = NSScreen.screens
        guard let screen = screens.max(by: { area(panel.frame.intersection($0.visibleFrame)) < area(panel.frame.intersection($1.visibleFrame)) }) else { return }
        let f = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(x: min(max(panel.frame.minX, f.minX), f.maxX - panel.frame.width),
            y: min(max(panel.frame.minY, f.minY), f.maxY - panel.frame.height)))
        savePosition()
    }
    private func area(_ rect: CGRect) -> CGFloat { rect.isNull ? 0 : rect.width * rect.height }
    @objc private func placeAtCorner() {
        guard let screen = panel?.screen ?? NSScreen.main else { return }
        panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - panel.frame.width - 18, y: screen.visibleFrame.maxY - panel.frame.height - 8))
        savePosition(); updateContrast()
    }
    private func updateContrast() {
        guard panel != nil, companion != nil else { return }
        switch defaults.string(forKey: "textMode") ?? "Automatic" {
        case "Light": companion.lightText = true
        case "Dark": companion.lightText = false
        default:
            if let screen = panel.screen ?? NSScreen.main {
                let scale = panel.frame.width / 260
                let labelY: CGFloat = 222
                let p = NSPoint(x: panel.frame.midX, y: panel.frame.maxY - labelY * scale)
                companion.lightText = contrast.lightText(at: p, screen: screen)
            }
        }
    }
    func menuNeedsUpdate(_ menu: NSMenu) { populateMenu() }
    private func item(_ title: String, action: Selector? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: ""); item.target = self; return item
    }
    private func populateMenu() {
        menu.removeAllItems()
        menu.addItem(item("Typing Companion"))
        menu.addItem(item(statusText))
        menu.addItem(.separator())
        for character in Character.allCases {
            let entry = item(character.rawValue, action: #selector(selectCharacter(_:)))
            entry.representedObject = character.rawValue
            entry.state = companion.character == character ? .on : .off
            menu.addItem(entry)
        }
        menu.addItem(.separator())
        menu.addItem(item(paused ? "Resume counting" : "Pause counting", action: #selector(togglePause)))
        menu.addItem(item(panel.isVisible ? "Hide companion" : "Show companion", action: #selector(toggleVisible)))
        menu.addItem(item("Move to top-right corner", action: #selector(placeAtCorner)))
        menu.addItem(item("Preview typing animation", action: #selector(previewAnimation)))
        menu.addItem(item("Settings…", action: #selector(openSettings(_:))))
        menu.addItem(.separator())
        let quit = item("Quit Typing Companion", action: #selector(quitApp)); quit.keyEquivalent = "q"; menu.addItem(quit)
    }
    @objc private func selectCharacter(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String, let character = Character(rawValue: name) else { return }
        companion.character = character; defaults.set(name, forKey: "character"); characterPopup?.selectItem(withTitle: name); updateContrast()
    }
    @objc private func togglePause() { defaults.set(!paused, forKey: "paused"); ledger.breakSession(); companion.clearKeys(); updateMonitoring() }
    @objc private func toggleVisible() { panel.isVisible ? panel.orderOut(nil) : panel.orderFrontRegardless() }
    @objc private func previewAnimation() {
        panel.orderFrontRegardless()
        companion.previewTyping()
    }
    @objc private func quitApp() { NSApp.terminate(nil) }

    @objc private func openSettings(_ sender: Any?) {
        if let settings { settings.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 645), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Typing Companion Settings"; window.isReleasedWhenClosed = false; window.center()
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 13
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView?.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 24)])
        func label(_ text: String, title: Bool = false) -> NSTextField {
            let l = NSTextField(wrappingLabelWithString: text); l.font = .systemFont(ofSize: title ? 23 : 12, weight: title ? .bold : .regular)
            l.preferredMaxLayoutWidth = 460; l.textColor = title ? .labelColor : .secondaryLabelColor
            stack.addArrangedSubview(l); l.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true; return l
        }
        _ = label("Your tiny typing companion", title: true)
        _ = label("Drag the character anywhere. Right-click it or use the keyboard icon in the menu bar to change settings.")
        statusLabel = label(statusText)
        let permission = NSButton(title: "Enable Input Monitoring…", target: self, action: #selector(requestPermission))
        stack.addArrangedSubview(permission)
        _ = label("Key positions are used briefly to move the paws to matching keys. No typed text, key codes, or app activity is saved or uploaded. Secure fields suspend animation. Held-key repeats and modifier-only presses are excluded from the daily count.")
        let charRow = NSStackView(); charRow.spacing = 15
        charRow.addArrangedSubview(NSTextField(labelWithString: "Character"))
        let popup = NSPopUpButton(); popup.addItems(withTitles: Character.allCases.map(\.rawValue)); popup.selectItem(withTitle: companion.character.rawValue)
        popup.target = self; popup.action = #selector(characterChanged(_:)); charRow.addArrangedSubview(popup); characterPopup = popup
        stack.addArrangedSubview(charRow)
        let textRow = NSStackView(); textRow.spacing = 15
        textRow.addArrangedSubview(NSTextField(labelWithString: "Counter text"))
        let color = NSPopUpButton(); color.addItems(withTitles: ["Automatic", "Light", "Dark"])
        color.selectItem(withTitle: defaults.string(forKey: "textMode") ?? "Automatic")
        color.target = self; color.action = #selector(textChanged(_:)); textRow.addArrangedSubview(color); textPopup = color
        stack.addArrangedSubview(textRow)
        _ = label("Automatic matches your wallpaper. Each counter theme has its own background to keep numbers readable. Choose Light or Dark for a fixed theme. No screen recording is used.")
        let sizeRow = NSStackView(); sizeRow.spacing = 15
        sizeRow.addArrangedSubview(NSTextField(labelWithString: "Size"))
        let slider = NSSlider(value: panel.frame.width, minValue: 180, maxValue: 360, target: self, action: #selector(sizeChanged(_:)))
        slider.widthAnchor.constraint(equalToConstant: 260).isActive = true; sizeRow.addArrangedSubview(slider); sizeSlider = slider
        stack.addArrangedSubview(sizeRow)
        let motion = NSButton(checkboxWithTitle: "Reduce animation", target: self, action: #selector(motionChanged(_:)))
        motion.state = companion.reduceMotion ? .on : .off; motionCheck = motion; stack.addArrangedSubview(motion)
        let weightRow = NSStackView(); weightRow.spacing = 12
        weightRow.addArrangedSubview(NSTextField(labelWithString: "Your weight (kg)"))
        let field = NSTextField(string: weight.map { String(format: "%.1f", $0) } ?? "")
        field.placeholderString = "Optional"; field.widthAnchor.constraint(equalToConstant: 90).isActive = true
        field.setAccessibilityLabel("Body weight in kilograms"); weightRow.addArrangedSubview(field); weightField = field
        weightRow.addArrangedSubview(NSButton(title: "Save", target: self, action: #selector(saveWeight)))
        stack.addArrangedSubview(weightRow)
        _ = label("Calories are a rough estimate ABOVE rest: 0.3 × weight (kg) × active typing hours. Active time is the interval between consecutive key presses no more than 5 seconds apart; idle time is excluded. Based on the 1.3-MET seated-typing category, not energy per key. Leave weight blank to hide the estimate. This is not a measured calorie burn.")
        let buttons = NSStackView(); buttons.spacing = 12
        buttons.addArrangedSubview(NSButton(title: "Preview animation", target: self, action: #selector(previewAnimation)))
        buttons.addArrangedSubview(NSButton(title: "Reconnect listener", target: self, action: #selector(reconnect)))
        stack.addArrangedSubview(buttons)
        settings = window; window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc private func requestPermission() {
        if !monitor.allowed { _ = CGRequestListenEventAccess() }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") { NSWorkspace.shared.open(url) }
    }
    @objc private func reconnect() { monitor.stop(); updateMonitoring(); statusLabel?.stringValue = statusText }
    @objc private func characterChanged(_ sender: NSPopUpButton) {
        guard let name = sender.titleOfSelectedItem, let character = Character(rawValue: name) else { return }
        companion.character = character; defaults.set(name, forKey: "character"); updateContrast()
    }
    @objc private func textChanged(_ sender: NSPopUpButton) { defaults.set(sender.titleOfSelectedItem, forKey: "textMode"); updateContrast() }
    @objc private func sizeChanged(_ sender: NSSlider) { defaults.set(sender.doubleValue, forKey: "size"); resizePanel(); keepOnScreen() }
    @objc private func motionChanged(_ sender: NSButton) { companion.reduceMotion = sender.state == .on; defaults.set(companion.reduceMotion, forKey: "reduceMotion") }
    @objc private func saveWeight() {
        let text = weightField?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if text.isEmpty { defaults.removeObject(forKey: "weightKG"); updateCounters(); return }
        let formatter = NumberFormatter(); formatter.numberStyle = .decimal
        guard let n = formatter.number(from: text)?.doubleValue, n.isFinite, (20...350).contains(n) else {
            let alert = NSAlert(); alert.messageText = "Enter a weight between 20 and 350 kg, or leave it blank."; alert.runModal(); return
        }
        defaults.set(n, forKey: "weightKG"); updateCounters()
    }
}

@main struct TypingCompanionMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
