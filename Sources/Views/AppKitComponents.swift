import AppKit

@MainActor
func label(_ text: String, size: CGFloat = 13, weight: NSFont.Weight = .regular, secondary: Bool = false) -> NSTextField {
    let field = NSTextField(wrappingLabelWithString: text)
    field.font = .systemFont(ofSize: size, weight: weight)
    field.textColor = secondary ? .secondaryLabelColor : .labelColor
    field.setContentCompressionResistancePriority(.required, for: .vertical)
    return field
}

@MainActor
func stack(_ views: [NSView], vertical: Bool = true, spacing: CGFloat = 12) -> NSStackView {
    let result = NSStackView(views: views)
    result.orientation = vertical ? .vertical : .horizontal
    result.alignment = vertical ? .leading : .centerY
    result.spacing = spacing
    return result
}

@MainActor
final class ActionButton: NSButton {
    var handler: (() -> Void)?
    private var copyFeedbackTask: Task<Void, Never>?
    private var titleBeforeCopy: String?
    init(_ title: String, symbol: String? = nil, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(frame: .zero)
        self.title = title
        bezelStyle = .rounded
        target = self; action = #selector(invoke)
        if let symbol { image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil); imagePosition = .imageLeading }
    }
    required init?(coder: NSCoder) { fatalError() }
    @objc private func invoke() { handler?() }
    func showCopiedFeedback() {
        if titleBeforeCopy == nil { titleBeforeCopy = title }
        copyFeedbackTask?.cancel()
        title = "Copied to clipboard"
        copyFeedbackTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            self?.resetCopyFeedback()
        }
    }
    func resetCopyFeedback() {
        copyFeedbackTask?.cancel()
        copyFeedbackTask = nil
        if let titleBeforeCopy { title = titleBeforeCopy }
        titleBeforeCopy = nil
    }
}

final class CardView: NSView {
    init(_ content: NSView) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 14
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            content.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
    override func updateLayer() {
        layer?.backgroundColor = TonicaAppearance.surface.cgColor
        layer?.borderColor = TonicaAppearance.border.cgColor
        layer?.borderWidth = 1
    }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); needsDisplay = true }
}

final class FlippedView: NSView { override var isFlipped: Bool { true } }

final class FocusRootView: NSView { override var acceptsFirstResponder: Bool { true } }
