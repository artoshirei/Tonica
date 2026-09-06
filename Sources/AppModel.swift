import Foundation

extension Notification.Name { static let tonicaModelChanged = Notification.Name("tonicaModelChanged") }

@MainActor
final class AppModel {
    private(set) var selectedFocus: SegmentFocus
    private(set) var chordDegree = 0
    var isPanelVisible = false
    var shortcutDescription = ""
    var instrument = Instrument(rawValue: UserDefaults.standard.string(forKey: "instrument") ?? "") ?? .piano {
        didSet { UserDefaults.standard.set(instrument.rawValue, forKey: "instrument"); changed() }
    }
    var showChordOnly = false { didSet { changed() } }
    var keepOnTop = UserDefaults.standard.bool(forKey: "keepOnTop") {
        didSet { UserDefaults.standard.set(keepOnTop, forKey: "keepOnTop"); changed() }
    }
    var showOnLaunch = UserDefaults.standard.object(forKey: "showOnLaunch") as? Bool ?? true {
        didSet { UserDefaults.standard.set(showOnLaunch, forKey: "showOnLaunch"); changed() }
    }
    let slices = CircleSlice.all
    init() {
        let index = UserDefaults.standard.integer(forKey: "selectedKey")
        let minor = UserDefaults.standard.bool(forKey: "minorKey")
        selectedFocus = SegmentFocus(index: (0..<12).contains(index) ? index : 0, ring: minor ? .minor : .major)
    }
    var slice: CircleSlice { slices[selectedFocus.index] }
    var isMinor: Bool { selectedFocus.ring == .minor }
    var keyTitle: String { "\(isMinor ? slice.minorScaleNotes[0] : slice.majorLabel) \(isMinor ? "minor" : "major")" }
    var scale: [String] { isMinor ? slice.minorScaleNotes : slice.scaleNotes }
    var chords: [String] { isMinor ? slice.minorDiatonicTriads : slice.diatonicTriads }
    var numerals: [String] { isMinor ? slice.minorRomanNumerals : slice.diatonicRomanNumerals }
    var chordNotes: [String] { [0, 2, 4].map { scale[(chordDegree + $0) % 7] } }
    var progressions: [ProgressionRecipe] { isMinor ? slice.minorProgressions : slice.majorProgressions }
    var displayedNotes: [String] { showChordOnly ? chordNotes : scale }
    func select(_ focus: SegmentFocus) {
        guard slices.indices.contains(focus.index) else { return }
        selectedFocus = SegmentFocus(index: focus.index, ring: focus.ring == .minor ? .minor : .major)
        chordDegree = focus.ring == .diminished ? 6 : 0
        UserDefaults.standard.set(focus.index, forKey: "selectedKey")
        UserDefaults.standard.set(isMinor, forKey: "minorKey")
        changed()
    }
    func selectChord(_ degree: Int) {
        guard (0..<7).contains(degree) else { return }
        chordDegree = degree
        changed()
    }
    func transpose(_ steps: Int) { select(SegmentFocus(index: (selectedFocus.index + steps + 12) % 12, ring: selectedFocus.ring)) }
    private func changed() { NotificationCenter.default.post(name: .tonicaModelChanged, object: self) }
}

// Spelling belongs to the key. Pitch classes belong to the instrument.
func midiPitchClass(_ note: String) -> Int {
    ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"].firstIndex(of: canonicalPitchClass(for: note))!
}

func ascendingMIDINotes(_ notes: [String], octave: Int = 4) -> [Int] {
    var previous = -1
    return notes.map { note in
        var value = 12 * (octave + 1) + midiPitchClass(note)
        while value <= previous { value += 12 }
        previous = value
        return value
    }
}
