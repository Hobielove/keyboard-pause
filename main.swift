import AppKit
import ApplicationServices

final class CleaningButton: NSButton {
    var fillColor = NSColor.systemGreen { didSet { needsDisplay = true } }
    override func draw(_ dirtyRect: NSRect) {
        (isHighlighted ? fillColor.blended(withFraction: 0.15, of: .black)! : fillColor).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 0, dy: 3), xRadius: 17, yRadius: 17).fill()
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 15, weight: .semibold), .foregroundColor: NSColor.white]
        let size = (title as NSString).size(withAttributes: attributes)
        (title as NSString).draw(at: NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2), withAttributes: attributes)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    var statusItem: NSStatusItem!
    var tap: CFMachPort?
    var source: CFRunLoopSource?
    var timer: Timer?
    var keyMonitor: Any?
    var policy = LockPolicy()
    var blocked = 0
    var interrupted = false
    let titleLabel = NSTextField(labelWithString: "给键盘，放个小假。")
    let subtitle = NSTextField(wrappingLabelWithString: "暂时屏蔽键盘输入，安心擦拭每一颗按键。")
    let keyboard = KeyboardView()
    let primary = CleaningButton(title: "开始清洁", target: nil, action: nil)
    var unlockItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let url = Bundle.main.url(forResource: "KeyboardPauseIcon", withExtension: "icns"), let icon = NSImage(contentsOf: url) {
            NSApp.applicationIconImage = icon
        }
        buildMenu()
        buildWindow()
        keyboard.updateAccessibility()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            guard let self, !self.policy.isLocked, self.window.isKeyWindow else { return event }
            self.updateKey(event)
            return event
        }
        NotificationCenter.default.addObserver(self, selector: #selector(clearKeys), name: NSApplication.didResignActiveNotification, object: nil)
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.screensDidSleepNotification] {
            center.addObserver(self, selector: #selector(systemPause), name: name, object: nil)
        }
        let timer = Timer(timeInterval: 0.2, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        refresh()
        showWindow()
    }

    func buildMenu() {
        let main = NSMenu()
        let root = NSMenuItem()
        main.addItem(root)
        let menu = NSMenu()
        menu.addItem(withTitle: "关于键盘小憩", action: #selector(about), keyEquivalent: "")
        menu.addItem(withTitle: "辅助功能设置…", action: #selector(openPermissions), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出键盘小憩", action: #selector(quit), keyEquivalent: "q")
        root.submenu = menu
        NSApp.mainMenu = main
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "键盘小憩")
        let tray = NSMenu()
        tray.addItem(withTitle: "显示键盘小憩", action: #selector(showWindow), keyEquivalent: "")
        unlockItem = tray.addItem(withTitle: "结束清洁 · 恢复键盘", action: #selector(manualStop), keyEquivalent: "")
        tray.addItem(.separator())
        tray.addItem(withTitle: "退出", action: #selector(quit), keyEquivalent: "")
        for item in tray.items { item.target = self }
        for item in menu.items { item.target = self }
        tray.autoenablesItems = false
        statusItem.menu = tray
    }

    func buildWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 340, height: 390), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "键盘小憩"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(calibratedRed: 0.96, green: 0.97, blue: 0.96, alpha: 1)
        window.appearance = NSAppearance(named: .aqua)
        window.center()
        let content = window.contentView!
        func add(_ view: NSView, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) {
            view.frame = NSRect(x: x, y: y, width: w, height: h)
            content.addSubview(view)
        }
        let brand = NSTextField(labelWithString: "KEYBOARD PAUSE  /  键盘小憩")
        brand.font = .systemFont(ofSize: 10, weight: .semibold)
        brand.textColor = .secondaryLabelColor
        brand.alignment = .center
        add(brand, 24, 347, 292, 18)
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.alignment = .center
        add(titleLabel, 24, 303, 292, 30)
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabelColor
        subtitle.alignment = .center
        add(subtitle, 24, 273, 292, 28)
        add(keyboard, 47, 166, 246, 83)
        primary.target = self
        primary.action = #selector(toggle)
        primary.bezelStyle = .rounded
        primary.isBordered = false
        primary.font = .systemFont(ofSize: 15, weight: .semibold)
        add(primary, 47, 97, 246, 40)
        let note = NSTextField(wrappingLabelWithString: "电源键 / Touch ID 不在屏蔽范围内。\n请勿将液体直接喷在键盘上。")
        note.font = .systemFont(ofSize: 10)
        note.textColor = .secondaryLabelColor
        note.alignment = .center
        add(note, 24, 37, 292, 30)
    }

    @objc func showWindow() {
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(keyboard)
        NSApp.activate(ignoringOtherApps: true)
    }
    func updateKey(_ event: NSEvent) {
        let down: Bool
        if event.type == .flagsChanged {
            down = event.keyCode == 57 ? event.modifierFlags.contains(.capsLock) : CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(event.keyCode))
        } else { down = event.type == .keyDown }
        keyboard.highlights.set(event.keyCode, down: down)
    }
    @objc func clearKeys() { keyboard.highlights.clear() }
    func windowDidResignKey(_ notification: Notification) { clearKeys() }
    @objc func openPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    @objc func toggle() {
        if policy.isLocked { manualStop(); return }
        guard AXIsProcessTrusted() else { openPermissions(); return }
        clearKeys()
        let modifiers: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand, .maskSecondaryFn]
        guard CGEventSource.flagsState(.combinedSessionState).intersection(modifiers).isEmpty else {
            subtitle.stringValue = "请先松开修饰键，再开始清洁。"
            return
        }
        let mask: CGEventMask = (1 << 10) | (1 << 11) | (1 << 12) | (1 << 14)
        guard let newTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask, callback: { _, type, event, info in
            guard let info else { return Unmanaged.passUnretained(event) }
            let app = Unmanaged<AppDelegate>.fromOpaque(info).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                app.interrupted = true
                app.policy.stop()
                return Unmanaged.passUnretained(event)
            }
            let media = type.rawValue == 14 && NSEvent(cgEvent: event)?.subtype.rawValue == 8
            if app.policy.shouldBlock(type: type.rawValue, mediaKey: media, now: ProcessInfo.processInfo.systemUptime) {
                if type == .keyDown || media { app.blocked += 1 }
                return nil
            }
            return Unmanaged.passUnretained(event)
        }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            subtitle.stringValue = "未能锁定，请检查辅助功能权限。"
            return
        }
        guard let newSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0) else {
            CFMachPortInvalidate(newTap)
            subtitle.stringValue = "未能锁定，请重新打开应用。"
            return
        }
        tap = newTap
        source = newSource
        blocked = 0
        interrupted = false
        policy.begin(now: ProcessInfo.processInfo.systemUptime)
        CFRunLoopAddSource(CFRunLoopGetMain(), newSource, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)
        guard CGEvent.tapIsEnabled(tap: newTap) else { stop("锁定未生效，键盘仍可使用"); return }
        window.level = .floating
        refresh()
    }
    func stop(_ message: String) {
        policy.stop()
        clearKeys()
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
        interrupted = false
        window?.level = .normal
        refresh()
        if message.contains("中断") || message.contains("未生效") { subtitle.stringValue = message }
    }
    @objc func manualStop() { stop("已恢复，可以继续工作") }
    @objc func systemPause() { if tap != nil { stop("已自动恢复键盘") } }
    @objc func tick() {
        if interrupted { stop("屏蔽已中断，键盘已恢复"); return }
        if policy.isLocked {
            if !AXIsProcessTrusted() || tap.map({ !CGEvent.tapIsEnabled(tap: $0) }) == true {
                stop("屏蔽已中断，键盘已恢复")
            } else if policy.remaining(now: ProcessInfo.processInfo.systemUptime) == 0 {
                stop("时间到，键盘已自动恢复")
            } else { refresh() }
        } else {
            refreshPermission()
        }
    }
    func refreshPermission() {
        let trusted = AXIsProcessTrusted()
        let color: NSColor = policy.isLocked ? .systemRed : (trusted ? .systemGreen : .systemGray)
        primary.fillColor = color
        keyboard.statusColor = color
        if !policy.isLocked { primary.title = trusted ? "开始清洁" : "开启辅助功能权限" }
        primary.needsDisplay = true
        primary.toolTip = trusted ? "清洁时屏蔽键盘；3 分钟后自动恢复。" : "在系统设置中开启辅助功能；若开关已开但未生效，请移除旧条目后重新添加此应用。"
    }

    func refresh() {
        let locked = policy.isLocked
        titleLabel.stringValue = locked ? "安心清洁，慢慢来。" : "给键盘，放个小假。"
        subtitle.stringValue = locked ? "键盘已锁定，用鼠标结束清洁。" : "暂时屏蔽输入，安心清洁。"
        primary.title = locked ? "结束清洁 · 恢复键盘" : "开始清洁"
        unlockItem?.isEnabled = locked
        if locked {
            let left = policy.remaining(now: ProcessInfo.processInfo.systemUptime)
            statusItem.button?.title = String(format: " %02d:%02d", left / 60, left % 60)
        } else { statusItem.button?.title = "" }
        refreshPermission()
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool { stop("键盘正常使用中"); return true }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showWindow(); return true }
    func applicationWillTerminate(_ notification: Notification) { stop("键盘正常使用中"); timer?.invalidate(); if let keyMonitor { NSEvent.removeMonitor(keyMonitor) } }
    @objc func quit() { stop("键盘正常使用中"); NSApp.terminate(nil) }
    @objc func about() {
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "键盘小憩", .applicationVersion: "1.2.1", .credits: NSAttributedString(string: "本地键盘清洁助手 · 无订阅 · 无到期限制\n不联网，不保存按键内容。")])
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.setActivationPolicy(.regular)
app.delegate = delegate
app.run()
