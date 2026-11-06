import AppKit

@main struct KeyboardTests {
    static func main() {
        let codes = KeyboardView.rows.flatMap { $0 }.compactMap { $0.code } + [125, 126]
        precondition(Set(codes).count == codes.count, "Each physical key must map uniquely")
        for row in KeyboardView.rows { precondition(row.reduce(0) { $0 + $1.units } == 15) }
        var state = KeyHighlights()
        state.set(0, down: true)
        state.set(55, down: true)
        state.set(0, down: true)
        precondition(state.held == [0, 55])
        state.set(0, down: false)
        precondition(state.held == [55])
        state.clear()
        precondition(state.held.isEmpty)
        print("PASS: layout widths, unique mappings, chord, key repeat, key release, focus reset")
        if CommandLine.arguments.count > 1 {
            _ = NSApplication.shared
            let view = KeyboardView(frame: NSRect(x: 0, y: 0, width: 640, height: 230))
            view.appearance = NSAppearance(named: .aqua)
            view.statusColor = .systemGreen
            for code: UInt16 in [0, 55, 126] { view.highlights.set(code, down: true) }
            let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
            view.cacheDisplay(in: view.bounds, to: bitmap)
            try! bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
        }
    }
}
