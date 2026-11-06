import AppKit

struct VisualKey {
    let label: String
    let code: UInt16?
    let units: CGFloat
    init(_ label: String, _ code: UInt16?, _ units: CGFloat = 1) {
        self.label = label; self.code = code; self.units = units
    }
}

struct KeyHighlights {
    private(set) var held = Set<UInt16>()
    mutating func set(_ code: UInt16, down: Bool) {
        if down { held.insert(code) } else { held.remove(code) }
    }
    mutating func clear() { held.removeAll() }
}

final class KeyboardView: NSView {
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    var statusColor: NSColor = .systemGray { didSet { needsDisplay = true } }
    var highlights = KeyHighlights() { didSet { needsDisplay = true; updateAccessibility() } }
    static let rows: [[VisualKey]] = [
        [.init("esc",53,1.5), .init("F1",122), .init("F2",120), .init("F3",99), .init("F4",118), .init("F5",96), .init("F6",97), .init("F7",98), .init("F8",100), .init("F9",101), .init("F10",109), .init("F11",103), .init("F12",111), .init("电源",nil,1.5)],
        [.init("`",50), .init("1",18), .init("2",19), .init("3",20), .init("4",21), .init("5",23), .init("6",22), .init("7",26), .init("8",28), .init("9",25), .init("0",29), .init("−",27), .init("=",24), .init("delete",51,2)],
        [.init("tab",48,1.5), .init("Q",12), .init("W",13), .init("E",14), .init("R",15), .init("T",17), .init("Y",16), .init("U",32), .init("I",34), .init("O",31), .init("P",35), .init("[",33), .init("]",30), .init("\\",42,1.5)],
        [.init("caps",57,1.75), .init("A",0), .init("S",1), .init("D",2), .init("F",3), .init("G",5), .init("H",4), .init("J",38), .init("K",40), .init("L",37), .init(";",41), .init("'",39), .init("return",36,2.25)],
        [.init("shift",56,2.25), .init("Z",6), .init("X",7), .init("C",8), .init("V",9), .init("B",11), .init("N",45), .init("M",46), .init(",",43), .init(".",47), .init("/",44), .init("shift",60,2.75)],
        [.init("fn",63), .init("ctrl",59), .init("⌥",58), .init("⌘",55,1.25), .init("space",49,5.5), .init("⌘",54,1.25), .init("⌥",61), .init("←",123), .init("↑↓",nil), .init("→",124)]
    ]
    func updateAccessibility() {
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        let allKeys = Self.rows.flatMap { $0 } + [VisualKey("↑",126), VisualKey("↓",125)]
        let labels = allKeys.filter { $0.code.map(highlights.held.contains) ?? false }.map { $0.label }
        setAccessibilityLabel(labels.isEmpty ? "虚拟键盘，未按下按键" : "虚拟键盘，按下：" + labels.joined(separator: "、"))
    }
    override func mouseDown(with event: NSEvent) { window?.makeFirstResponder(self) }
    override func keyDown(with event: NSEvent) { /* Display only: no text field or system key synthesis. */ }
    override func keyUp(with event: NSEvent) {}
    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedWhite: 0.88, alpha: 1).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 16, yRadius: 16).fill()
        let unit = (bounds.width - 24) / 15
        let rowHeight = (bounds.height - 24) / 6
        for (r, row) in Self.rows.enumerated() {
            var x: CGFloat = 12
            for key in row {
                let rect = NSRect(x: x + 1.5, y: 12 + CGFloat(r) * rowHeight + 1.5, width: unit * key.units - 3, height: rowHeight - 3)
                if key.label == "↑↓" {
                    let half = (rect.height - 2) / 2
                    drawKey(.init("↑",126), NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: half))
                    drawKey(.init("↓",125), NSRect(x: rect.minX, y: rect.minY + half + 2, width: rect.width, height: half))
                } else { drawKey(key, rect) }
                x += unit * key.units
            }
        }
    }
    private func drawKey(_ key: VisualKey, _ rect: NSRect) {
        let pressed = key.code.map(highlights.held.contains) ?? false
        (pressed ? NSColor.systemBlue : statusColor).setFill()
        let path = NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3)
        path.fill()

    }
}
