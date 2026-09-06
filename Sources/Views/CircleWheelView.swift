import AppKit

final class CircleWheelView: NSView {
    let model: AppModel
    private var keys: [WheelKey] = []
    init(model: AppModel) {
        self.model = model
        super.init(frame: .zero)
        for ring in [RingKind.major, .minor] {
            for index in 0..<12 {
                let button = WheelKey(index: index, ring: ring, model: model)
                addSubview(button); keys.append(button)
            }
        }
        setAccessibilityElement(false)
    }
    required init?(coder: NSCoder) { fatalError() }
    override var intrinsicContentSize: NSSize { NSSize(width: 380, height: 380) }
    override func layout() { super.layout(); keys.forEach { $0.frame = bounds } }
    func refresh() { keys.forEach { $0.refresh() }; needsDisplay = true }
    override func draw(_ dirtyRect: NSRect) {
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let title = model.isMinor ? model.slice.minorLabel : model.slice.majorLabel
        let sub = model.isMinor ? "MINOR" : "MAJOR"
        for (text, size, y, color) in [(title, CGFloat(30), CGFloat(0), NSColor.labelColor), (sub, CGFloat(10), CGFloat(-22), NSColor.secondaryLabelColor)] {
            let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: .semibold), .foregroundColor: color]
            let s = (text as NSString).size(withAttributes: attrs)
            (text as NSString).draw(at: NSPoint(x: center.x - s.width / 2, y: center.y + y - s.height / 2), withAttributes: attrs)
        }
    }
}

private final class WheelKey: NSButton {
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
    let index: Int
    let ring: RingKind
    let model: AppModel
    init(index: Int, ring: RingKind, model: AppModel) {
        self.index = index; self.ring = ring; self.model = model
        super.init(frame: .zero)
        focusRingType = .none
        isBordered = false
        title = model.slices[index].label(for: ring)
        target = self; action = #selector(selectKey)
        setAccessibilityLabel("\(ring == .major ? model.slices[index].majorLabel : model.slices[index].minorScaleNotes[0]) \(ring == .major ? "major" : "minor")")
    }
    required init?(coder: NSCoder) { fatalError() }
    private var selected: Bool { model.selectedFocus == SegmentFocus(index: index, ring: ring) }
    private var radius: CGFloat { min(bounds.width, bounds.height) / 2 - 4 }
    private var outer: CGFloat { radius * (ring == .major ? 1 : 0.71) }
    private var inner: CGFloat { radius * (ring == .major ? 0.73 : 0.44) }
    private var angle: CGFloat { 90 - CGFloat(index) * 30 }
    private var shape: NSBezierPath {
        let path = NSBezierPath()
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        path.appendArc(withCenter: center, radius: outer, startAngle: angle - 14, endAngle: angle + 14)
        path.appendArc(withCenter: center, radius: inner, startAngle: angle + 14, endAngle: angle - 14, clockwise: true)
        path.close()
        return path
    }
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard radius > 0 else { return nil }
        let local = convert(point, from: superview)
        return shape.contains(local) ? self : nil
    }
    func refresh() { setAccessibilityValue(selected ? "Selected" : ""); needsDisplay = true }
    @objc private func selectKey() { model.select(SegmentFocus(index: index, ring: ring)) }
    override func draw(_ dirtyRect: NSRect) {
        guard radius > 0 else { return }
        let fill = selected ? TonicaAppearance.accent : model.slices[index].palette.withAlphaComponent(ring == .major ? 0.22 : 0.10)
        fill.setFill(); shape.fill()
        if isHighlighted { NSColor.labelColor.withAlphaComponent(0.12).setFill(); shape.fill() }
        if window?.firstResponder === self {
            NSColor.keyboardFocusIndicatorColor.setStroke(); let p = shape; p.lineWidth = 3; p.stroke()
        }
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: ring == .major ? 17 : 12, weight: selected ? .bold : .medium), .foregroundColor: selected ? NSColor.black : NSColor.labelColor]
        let s = (title as NSString).size(withAttributes: attrs)
        let radians = angle * .pi / 180
        let r = (inner + outer) / 2
        (title as NSString).draw(at: NSPoint(x: bounds.midX + cos(radians) * r - s.width / 2, y: bounds.midY + sin(radians) * r - s.height / 2), withAttributes: attrs)
    }
}
