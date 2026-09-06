import AppKit

private let blackKeyPitchClasses: Set<Int> = [1, 3, 6, 8, 10]

final class InstrumentView: NSView {
    let model: AppModel
    let player: NotePlayer
    private var notes: [InstrumentNoteButton] = []
    init(model: AppModel, player: NotePlayer) {
        self.model = model; self.player = player
        super.init(frame: .zero)
        rebuild()
    }
    required init?(coder: NSCoder) { fatalError() }
    override var intrinsicContentSize: NSSize { NSSize(width: 400, height: model.instrument == .piano ? 150 : 190) }
    func rebuild() {
        notes.forEach { $0.removeFromSuperview() }; notes.removeAll()
        if model.instrument == .piano {
            let pitches = (60...84).filter { !blackKeyPitchClasses.contains($0 % 12) }
                + (60...84).filter { blackKeyPitchClasses.contains($0 % 12) }
            for midi in pitches { addNote(midi, string: -1, fret: -1) }
        } else {
            // High E at the top, as in a conventional horizontal fretboard diagram.
            for (string, open) in [40, 45, 50, 55, 59, 64].enumerated() {
                for fret in 0...12 { addNote(open + fret, string: string, fret: fret) }
            }
        }
        invalidateIntrinsicContentSize(); needsLayout = true; needsDisplay = true
    }
    private func addNote(_ midi: Int, string: Int, fret: Int) {
        let pc = midi % 12
        let spelling = model.scale.first { midiPitchClass($0) == pc } ?? ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"][pc]
        let active = model.displayedNotes.contains { midiPitchClass($0) == pc }
        let root = midiPitchClass(model.showChordOnly ? model.chordNotes[0] : model.scale[0]) == pc
        let button = InstrumentNoteButton(midi: midi, spelling: spelling, highlighted: active, root: root, guitar: string >= 0, accent: TonicaAppearance.accent)
        button.string = string; button.fret = fret
        button.onPlay = { [weak self] in self?.player.play([midi]) }
        button.setAccessibilityLabel(string < 0 ? "Play \(spelling)\(midi / 12 - 1)" : "Play \(spelling), string \(6 - string), fret \(fret)")
        notes.append(button); addSubview(button)
    }
    override func layout() {
        super.layout()
        // Auto Layout can visit this view before it receives its final width.
        guard bounds.width >= 26, bounds.height >= 4 else {
            notes.forEach { $0.frame = .zero }
            return
        }
        if model.instrument == .piano {
            let whites = notes.filter { !$0.blackKey }
            let width = bounds.width / CGFloat(whites.count)
            for (i, button) in whites.enumerated() { button.frame = NSRect(x: CGFloat(i) * width, y: 0, width: width - 1, height: bounds.height) }
            for button in notes where button.blackKey {
                let before = whites.filter { $0.midi < button.midi }.count
                button.frame = NSRect(x: CGFloat(before) * width - width * 0.32, y: bounds.height * 0.39, width: width * 0.64, height: bounds.height * 0.61)
            }
        } else {
            let width = bounds.width / 13
            for button in notes { button.frame = NSRect(x: CGFloat(button.fret) * width + 1, y: 22 + CGFloat(button.string) * 26, width: width - 2, height: 24) }
        }
    }
    override func draw(_ dirtyRect: NSRect) {
        guard model.instrument == .guitar else { return }
        let width = bounds.width / 13
        NSColor.separatorColor.setStroke()
        for string in 0..<6 {
            let p = NSBezierPath(); p.move(to: NSPoint(x: width, y: 34 + CGFloat(string) * 26)); p.line(to: NSPoint(x: bounds.width, y: 34 + CGFloat(string) * 26)); p.stroke()
        }
        for fret in 0...12 {
            let p = NSBezierPath(); p.lineWidth = fret == 0 ? 3 : 1
            p.move(to: NSPoint(x: CGFloat(fret + 1) * width, y: 28)); p.line(to: NSPoint(x: CGFloat(fret + 1) * width, y: 170)); p.stroke()
            let text = fret == 0 ? "0" : String(fret)
            (text as NSString).draw(at: NSPoint(x: CGFloat(fret) * width + width / 2 - 4, y: 2), withAttributes: [.font: NSFont.systemFont(ofSize: 10), .foregroundColor: NSColor.secondaryLabelColor])
        }
    }
}

private final class InstrumentNoteButton: NSButton {
    override var isFlipped: Bool { false }
    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        needsDisplay = true
        return accepted
    }
    override func resignFirstResponder() -> Bool {
        let accepted = super.resignFirstResponder()
        needsDisplay = true
        return accepted
    }
    let midi: Int
    let spelling: String
    let highlightedNote: Bool
    let root: Bool
    let guitar: Bool
    let accent: NSColor
    var string = -1
    var fret = -1
    var onPlay: (() -> Void)?
    var blackKey: Bool { blackKeyPitchClasses.contains(midi % 12) }
    init(midi: Int, spelling: String, highlighted: Bool, root: Bool, guitar: Bool, accent: NSColor) {
        self.midi = midi; self.spelling = spelling; highlightedNote = highlighted; self.root = root; self.guitar = guitar; self.accent = accent
        super.init(frame: .zero)
        focusRingType = .none
        isBordered = false; title = spelling
        target = self; action = #selector(play)
    }
    required init?(coder: NSCoder) { fatalError() }
    @objc private func play() { onPlay?() }
    override func draw(_ dirtyRect: NSRect) {
        guard bounds.width >= 4, bounds.height >= 4 else { return }
        let rect = bounds.insetBy(dx: 1, dy: 1)
        if !guitar {
            (blackKey ? NSColor(white: 0.025, alpha: 1) : NSColor(white: 0.17, alpha: 1)).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()
        }
        if highlightedNote || isHighlighted {
            accent.withAlphaComponent(root || isHighlighted ? 1 : 0.5).setFill()
            let marker = guitar ? rect : NSRect(x: bounds.midX - min(10, bounds.width / 2 - 2), y: 22, width: min(20, bounds.width - 4), height: 20)
            NSBezierPath(roundedRect: marker, xRadius: guitar ? 7 : 10, yRadius: guitar ? 7 : 10).fill()
        }
        if highlightedNote || (!guitar && !blackKey) || (guitar && fret == 0) {
            let foreground: NSColor = guitar ? (highlightedNote ? (root ? .black : .white) : .secondaryLabelColor) : NSColor(white: 0.9, alpha: 1)
            let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: guitar ? 10 : 9, weight: root ? .bold : .medium), .foregroundColor: foreground]
            let s = (spelling as NSString).size(withAttributes: attrs)
            (spelling as NSString).draw(at: NSPoint(x: bounds.midX - s.width / 2, y: guitar ? bounds.midY - s.height / 2 : 5), withAttributes: attrs)
        }
        if window?.firstResponder === self { NSColor.keyboardFocusIndicatorColor.setStroke(); let p = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4); p.lineWidth = 2; p.stroke() }
    }
}
