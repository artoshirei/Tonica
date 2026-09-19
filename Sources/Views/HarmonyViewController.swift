import AppKit

final class HarmonyViewController: NSViewController {
    let model: AppModel
    private let player = NotePlayer()
    private lazy var wheel = CircleWheelView(model: model)
    private lazy var instrumentView = InstrumentView(model: model, player: player)
    private let keyTitle = label("", size: 30, weight: .bold)
    private let signature = label("", secondary: true)
    private let scaleNotes = (0..<7).map { _ in label("", size: 19, weight: .medium) }
    private let chordTitle = label("", size: 19, weight: .semibold)
    private let chordNotes = label("", secondary: true)
    private let scaleCaption = label("", secondary: true)
    private let instrumentCaption = label("", size: 11, secondary: true)
    private let relatives = label("", size: 12, secondary: true)
    private let chordsRow = NSStackView()
    private let progressionsStack = NSStackView()
    private var chordButtons: [ActionButton] = []
    private var progressionButtons: [ActionButton] = []
    private var progressionPlayButtons: [ActionButton] = []
    private var copyScaleButton: ActionButton!
    private var copyChordButton: ActionButton!
    private var instrumentPicker: NSSegmentedControl!
    private var notesPicker: NSSegmentedControl!
    init(model: AppModel) { self.model = model; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }
    override func loadView() {
        view = FocusRootView()
        let heading = stack([label("TONICA", size: 12, weight: .bold, secondary: true), label("Find your next chord.", size: 24, weight: .semibold)], spacing: 6)
        let nav = stack([
            ActionButton("Fourth", symbol: "arrow.left") { [weak self] in self?.model.transpose(-1) },
            ActionButton("Fifth", symbol: "arrow.right") { [weak self] in self?.model.transpose(1) }
        ], vertical: false)
        let settings = ActionButton("Settings…", symbol: "gearshape") { AppController.shared.openSettingsWindow() }
        let keys = label("", size: 11)
        let hint = NSMutableAttributedString()
        for (key, action) in [("← →", "fourths and fifths     "), ("↑ ↓", "major or minor\n"), ("1–7", "chords     "), ("Space", "play chord     "), ("Return", "play scale")] {
            hint.append(NSAttributedString(string: key + "  ", attributes: [.font: NSFont.systemFont(ofSize: 11, weight: .semibold), .foregroundColor: NSColor.secondaryLabelColor]))
            hint.append(NSAttributedString(string: action, attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.tertiaryLabelColor]))
        }
        keys.attributedStringValue = hint
        let left = stack([heading, wheel, label("Outer ring: major  ·  Inner ring: relative minor", size: 11, secondary: true), nav, relatives, NSView(), keys, settings], spacing: 16)
        left.translatesAutoresizingMaskIntoConstraints = false
        left.widthAnchor.constraint(equalToConstant: 380).isActive = true
        wheel.widthAnchor.constraint(equalTo: left.widthAnchor).isActive = true
        wheel.heightAnchor.constraint(equalTo: wheel.widthAnchor).isActive = true

        let scalePlay = ActionButton("Play scale", symbol: "play.fill") { [weak self] in self?.playScale() }
        copyScaleButton = ActionButton("Copy", symbol: "doc.on.doc") { [weak self] in
            guard let self else { return }
            self.copy("\(self.model.keyTitle): \(self.model.scale.joined(separator: " "))", from: self.copyScaleButton)
        }
        // Fixed columns keep each degree under its note in every key.
        let scaleRow = stack(scaleNotes.enumerated().map { degree, note in
            let column = stack([note, label(String(degree + 1), size: 11, secondary: true)], spacing: 4)
            column.widthAnchor.constraint(equalToConstant: 46).isActive = true
            return column
        }, vertical: false, spacing: 0)
        let scaleCard = CardView(stack([stack([label("SCALE", size: 10, weight: .bold, secondary: true), scalePlay, copyScaleButton], vertical: false, spacing: 16), scaleRow, scaleCaption], spacing: 10))
        chordsRow.orientation = .horizontal; chordsRow.distribution = .fillEqually; chordsRow.spacing = 6
        for degree in 0..<7 {
            let button = ActionButton("") { [weak self] in self?.model.selectChord(degree); self?.playChord() }
            button.font = .systemFont(ofSize: 12, weight: .medium)
            button.setButtonType(.pushOnPushOff)
            chordButtons.append(button); chordsRow.addArrangedSubview(button)
        }
        let playChord = ActionButton("Play chord", symbol: "speaker.wave.2") { [weak self] in self?.playChord() }
        copyChordButton = ActionButton("Copy", symbol: "doc.on.doc") { [weak self] in
            guard let self else { return }
            self.copy("\(self.model.chords[self.model.chordDegree]): \(self.model.chordNotes.joined(separator: " "))", from: self.copyChordButton)
        }
        let chordCard = CardView(stack([label("CHORDS IN THIS KEY", size: 10, weight: .bold, secondary: true), chordsRow, stack([chordTitle, chordNotes], vertical: false), stack([playChord, copyChordButton], vertical: false)], spacing: 12))
        chordsRow.widthAnchor.constraint(equalTo: chordCard.widthAnchor, constant: -36).isActive = true
        instrumentPicker = NSSegmentedControl(labels: Instrument.allCases.map(\.title), trackingMode: .selectOne, target: self, action: #selector(changeInstrument))
        notesPicker = NSSegmentedControl(labels: ["Scale", "Chord"], trackingMode: .selectOne, target: self, action: #selector(changeNotes))
        let instrumentCard = CardView(stack([stack([instrumentPicker, notesPicker], vertical: false, spacing: 16), instrumentView, instrumentCaption], spacing: 12))
        instrumentView.widthAnchor.constraint(equalTo: instrumentCard.widthAnchor, constant: -36).isActive = true
        instrumentView.setContentHuggingPriority(.required, for: .vertical)
        progressionsStack.orientation = .vertical; progressionsStack.alignment = .leading; progressionsStack.spacing = 8
        for index in 0..<2 {
            let play = ActionButton("", symbol: "play.fill") { [weak self] in self?.playProgression(index) }
            let button = ActionButton("", symbol: "doc.on.doc") { [weak self] in self?.copyProgression(index) }
            button.imagePosition = .imageTrailing
            progressionPlayButtons.append(play); progressionButtons.append(button)
            progressionsStack.addArrangedSubview(stack([play, button], vertical: false, spacing: 6))
        }
        let progressionCard = CardView(stack([label("TRY A PROGRESSION", size: 10, weight: .bold, secondary: true), progressionsStack, label("Play a progression, or click it to copy its chords.", size: 11, secondary: true)], spacing: 10))
        let details = stack([keyTitle, signature, scaleCard, chordCard, instrumentCard, progressionCard], spacing: 14)
        for card in [scaleCard, chordCard, instrumentCard, progressionCard] { card.widthAnchor.constraint(equalTo: details.widthAnchor).isActive = true }
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true; scroll.drawsBackground = false
        let document = FlippedView(); scroll.documentView = document
        document.translatesAutoresizingMaskIntoConstraints = false
        details.translatesAutoresizingMaskIntoConstraints = false; document.addSubview(details)
        NSLayoutConstraint.activate([
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            details.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 2),
            details.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -16),
            details.topAnchor.constraint(equalTo: document.topAnchor),
            details.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -24)
        ])
        let separator = NSBox(); separator.boxType = .separator
        for child in [left, separator, scroll] { child.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(child) }
        NSLayoutConstraint.activate([
            left.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            left.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            left.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -24),
            separator.leadingAnchor.constraint(equalTo: left.trailingAnchor, constant: 24),
            separator.widthAnchor.constraint(equalToConstant: 1), separator.topAnchor.constraint(equalTo: view.topAnchor), separator.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: separator.trailingAnchor, constant: 24),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            scroll.topAnchor.constraint(equalTo: view.topAnchor, constant: 24), scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: .tonicaModelChanged, object: model)
        refresh()
    }
    @objc private func refresh() {
        copyScaleButton.resetCopyFeedback()
        copyChordButton.resetCopyFeedback()
        keyTitle.stringValue = model.keyTitle
        signature.stringValue = "\(model.slice.signature)  ·  \(model.isMinor ? "Relative major: " + model.slice.majorLabel : "Relative minor: " + model.slice.minorLabel)"
        for (note, field) in zip(model.scale, scaleNotes) { field.stringValue = note }
        scaleCaption.stringValue = "Natural minor. Raise degree 7 for harmonic minor."
        scaleCaption.isHidden = !model.isMinor
        chordTitle.stringValue = model.chords[model.chordDegree]
        chordNotes.stringValue = model.chordNotes.joined(separator: "  ·  ")
        for (degree, button) in chordButtons.enumerated() {
            button.title = "\(model.numerals[degree])  \(model.chords[degree])"
            button.state = degree == model.chordDegree ? .on : .off
            button.setAccessibilityLabel("\(model.numerals[degree]), \(model.chords[degree]) chord")
        }
        for (index, button) in progressionButtons.enumerated() {
            button.resetCopyFeedback()
            let recipe = model.progressions[index]
            button.title = "\(recipe.numerals)    \(recipe.chords.joined(separator: "  →  "))   "
            button.toolTip = "Copy \(recipe.title)"
            progressionPlayButtons[index].toolTip = "Play \(recipe.title)"
            progressionPlayButtons[index].setAccessibilityLabel("Play \(recipe.title)")
        }
        instrumentPicker.selectedSegment = Instrument.allCases.firstIndex(of: model.instrument)!
        notesPicker.selectedSegment = model.showChordOnly ? 1 : 0
        instrumentCaption.stringValue = model.instrument == .piano ? "C4 to C6  ·  Filled marker: root  ·  Click a key to listen" : "Standard tuning E A D G B E  ·  High E on top  ·  Filled marker: root"
        let previous = model.slices[(model.selectedFocus.index + 11) % 12]
        let next = model.slices[(model.selectedFocus.index + 1) % 12]
        relatives.stringValue = "Neighboring keys share six notes.\n\(previous.label(for: model.selectedFocus.ring))  ←  \(model.keyTitle)  →  \(next.label(for: model.selectedFocus.ring))"
        wheel.refresh(); instrumentView.rebuild()
    }
    @objc private func changeInstrument() { model.instrument = Instrument.allCases[instrumentPicker.selectedSegment] }
    @objc private func changeNotes() { model.showChordOnly = notesPicker.selectedSegment == 1 }
    private func copyProgression(_ index: Int) { copy(model.progressions[index].chords.joined(separator: " → "), from: progressionButtons[index]) }
    private func copy(_ text: String, from button: ActionButton) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        button.showCopiedFeedback()
    }
    private func playScale() { player.play(ascendingMIDINotes(model.scale + [model.scale[0]]).map { [$0] }, spacing: 0.25) }
    private func playChord() { player.play([ascendingMIDINotes(model.chordNotes)]) }
    private func playProgression(_ index: Int) {
        let chords = model.progressions[index].chords.compactMap(model.chords.firstIndex(of:))
        player.play(chords.map { ascendingMIDINotes(model.triad($0)) }, spacing: 0.7)
    }
    // Reached when no focused control wants the key, so Space still presses a focused button.
    override func keyDown(with event: NSEvent) {
        guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return super.keyDown(with: event) }
        switch event.specialKey {
        case .leftArrow: model.transpose(-1)
        case .rightArrow: model.transpose(1)
        case .upArrow, .downArrow: model.select(SegmentFocus(index: model.selectedFocus.index, ring: model.isMinor ? .major : .minor))
        case .carriageReturn, .enter: playScale()
        default:
            if event.charactersIgnoringModifiers == " " { playChord() }
            else if let degree = Int(event.charactersIgnoringModifiers ?? ""), (1...7).contains(degree) { model.selectChord(degree - 1); playChord() }
            else { super.keyDown(with: event) }
        }
    }
}
