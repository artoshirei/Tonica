import SwiftUI

struct ProgressionRecipe: Identifiable, Hashable {
    let id: String
    let title: String
    let numerals: String
    let chords: [String]
}

enum RingKind: String, CaseIterable, Identifiable {
    case major
    case minor
    case diminished

    var id: String { rawValue }

    var title: String {
        switch self {
        case .major:
            return "Major Key"
        case .minor:
            return "Relative Minor"
        case .diminished:
            return "Leading Diminished"
        }
    }

    var subtitle: String {
        switch self {
        case .major:
            return "The home key on this slice."
        case .minor:
            return "The inside minor that shares the same signature."
        case .diminished:
            return "The tension chord built from the seventh scale degree."
        }
    }
}

struct SegmentFocus: Equatable {
    let index: Int
    let ring: RingKind
}

struct CircleSlice: Identifiable, Hashable {
    let id = UUID()
    let majorLabel: String
    let minorLabel: String
    let diminishedLabel: String
    let signature: String
    let scaleNotes: [String]
    let palette: Color

    var diatonicTriads: [String] {
        [
            majorLabel,
            minorChord(for: 1),
            minorChord(for: 2),
            scaleNotes[3],
            scaleNotes[4],
            minorLabel,
            diminishedLabel
        ]
    }

    var diatonicRomanNumerals: [String] {
        ["I", "ii", "iii", "IV", "V", "vi", "vii°"]
    }

    var majorTriadNotes: [String] {
        [scaleNotes[0], scaleNotes[2], scaleNotes[4]]
    }

    var minorScaleNotes: [String] {
        [scaleNotes[5], scaleNotes[6], scaleNotes[0], scaleNotes[1], scaleNotes[2], scaleNotes[3], scaleNotes[4]]
    }

    var minorTriadNotes: [String] {
        [minorScaleNotes[0], minorScaleNotes[2], minorScaleNotes[4]]
    }

    var minorDiatonicTriads: [String] {
        [
            minorLabel,
            diminishedLabel,
            minorScaleNotes[2],
            minorChord(note: minorScaleNotes[3]),
            minorChord(note: minorScaleNotes[4]),
            minorScaleNotes[5],
            minorScaleNotes[6]
        ]
    }

    var minorRomanNumerals: [String] {
        ["i", "ii°", "III", "iv", "v", "VI", "VII"]
    }

    var diminishedTriadNotes: [String] {
        [scaleNotes[6], scaleNotes[1], scaleNotes[3]]
    }

    var cadence: [String] {
        [minorChord(for: 1), scaleNotes[4], majorLabel]
    }

    var majorProgressions: [ProgressionRecipe] {
        [
            ProgressionRecipe(
                id: "pop-lift",
                title: "Pop lift",
                numerals: "I – V – vi – IV",
                chords: [majorLabel, scaleNotes[4], minorLabel, scaleNotes[3]]
            ),
            ProgressionRecipe(
                id: "turnaround",
                title: "Turnaround",
                numerals: "ii – V – I",
                chords: [minorChord(for: 1), scaleNotes[4], majorLabel]
            )
        ]
    }

    var minorProgressions: [ProgressionRecipe] {
        [
            ProgressionRecipe(
                id: "moody-loop",
                title: "Moody loop",
                numerals: "i – VI – III – VII",
                chords: [minorLabel, minorScaleNotes[5], minorScaleNotes[2], minorScaleNotes[6]]
            ),
            ProgressionRecipe(
                id: "cinematic",
                title: "Cinematic",
                numerals: "i – iv – VII – III",
                chords: [
                    minorLabel,
                    minorChord(note: minorScaleNotes[3]),
                    minorScaleNotes[6],
                    minorScaleNotes[2]
                ]
            )
        ]
    }

    func chordNotes(for ring: RingKind) -> [String] {
        switch ring {
        case .major:
            return majorTriadNotes
        case .minor:
            return minorTriadNotes
        case .diminished:
            return diminishedTriadNotes
        }
    }

    func label(for ring: RingKind) -> String {
        switch ring {
        case .major:
            return majorLabel
        case .minor:
            return minorLabel
        case .diminished:
            return diminishedLabel
        }
    }

    func sharedScaleNotes(with other: CircleSlice) -> [String] {
        scaleNotes.filter(other.scaleNotes.contains)
    }

    func sharedDiatonicChords(with other: CircleSlice) -> [String] {
        diatonicTriads.filter(other.diatonicTriads.contains)
    }

    private func minorChord(for degree: Int) -> String {
        "\(scaleNotes[degree])m"
    }

    private func minorChord(note: String) -> String {
        "\(note)m"
    }
}

extension CircleSlice {
    static let all: [CircleSlice] = [
        CircleSlice(
            majorLabel: "C",
            minorLabel: "Am",
            diminishedLabel: "Bdim",
            signature: "0 sharps / 0 flats",
            scaleNotes: ["C", "D", "E", "F", "G", "A", "B"],
            palette: Color(red: 0.94, green: 0.82, blue: 0.35)
        ),
        CircleSlice(
            majorLabel: "G",
            minorLabel: "Em",
            diminishedLabel: "F#dim",
            signature: "1 sharp",
            scaleNotes: ["G", "A", "B", "C", "D", "E", "F#"],
            palette: Color(red: 0.35, green: 0.72, blue: 0.66)
        ),
        CircleSlice(
            majorLabel: "D",
            minorLabel: "Bm",
            diminishedLabel: "C#dim",
            signature: "2 sharps",
            scaleNotes: ["D", "E", "F#", "G", "A", "B", "C#"],
            palette: Color(red: 0.46, green: 0.79, blue: 0.89)
        ),
        CircleSlice(
            majorLabel: "A",
            minorLabel: "F#m",
            diminishedLabel: "G#dim",
            signature: "3 sharps",
            scaleNotes: ["A", "B", "C#", "D", "E", "F#", "G#"],
            palette: Color(red: 0.20, green: 0.34, blue: 0.53)
        ),
        CircleSlice(
            majorLabel: "E",
            minorLabel: "C#m",
            diminishedLabel: "D#dim",
            signature: "4 sharps",
            scaleNotes: ["E", "F#", "G#", "A", "B", "C#", "D#"],
            palette: Color(red: 0.48, green: 0.55, blue: 0.64)
        ),
        CircleSlice(
            majorLabel: "B",
            minorLabel: "G#m",
            diminishedLabel: "A#dim",
            signature: "5 sharps",
            scaleNotes: ["B", "C#", "D#", "E", "F#", "G#", "A#"],
            palette: Color(red: 0.33, green: 0.28, blue: 0.33)
        ),
        CircleSlice(
            majorLabel: "F#/Gb",
            minorLabel: "D#m",
            diminishedLabel: "E#dim",
            signature: "6 sharps / 6 flats",
            scaleNotes: ["F#", "G#", "A#", "B", "C#", "D#", "E#"],
            palette: Color(red: 0.58, green: 0.56, blue: 0.60)
        ),
        CircleSlice(
            majorLabel: "Db",
            minorLabel: "Bbm",
            diminishedLabel: "Cdim",
            signature: "5 flats",
            scaleNotes: ["Db", "Eb", "F", "Gb", "Ab", "Bb", "C"],
            palette: Color(red: 0.86, green: 0.43, blue: 0.36)
        ),
        CircleSlice(
            majorLabel: "Ab",
            minorLabel: "Fm",
            diminishedLabel: "Gdim",
            signature: "4 flats",
            scaleNotes: ["Ab", "Bb", "C", "Db", "Eb", "F", "G"],
            palette: Color(red: 0.90, green: 0.55, blue: 0.46)
        ),
        CircleSlice(
            majorLabel: "Eb",
            minorLabel: "Cm",
            diminishedLabel: "Ddim",
            signature: "3 flats",
            scaleNotes: ["Eb", "F", "G", "Ab", "Bb", "C", "D"],
            palette: Color(red: 0.91, green: 0.65, blue: 0.36)
        ),
        CircleSlice(
            majorLabel: "Bb",
            minorLabel: "Gm",
            diminishedLabel: "Adim",
            signature: "2 flats",
            scaleNotes: ["Bb", "C", "D", "Eb", "F", "G", "A"],
            palette: Color(red: 0.91, green: 0.72, blue: 0.44)
        ),
        CircleSlice(
            majorLabel: "F",
            minorLabel: "Dm",
            diminishedLabel: "Edim",
            signature: "1 flat",
            scaleNotes: ["F", "G", "A", "Bb", "C", "D", "E"],
            palette: Color(red: 0.95, green: 0.78, blue: 0.40)
        )
    ]
}

private let canonicalPitchClasses: [String: String] = [
    "B#": "C",
    "C": "C",
    "C#": "C#",
    "Db": "C#",
    "D": "D",
    "D#": "D#",
    "Eb": "D#",
    "E": "E",
    "Fb": "E",
    "E#": "F",
    "F": "F",
    "F#": "F#",
    "Gb": "F#",
    "F#/Gb": "F#",
    "G": "G",
    "G#": "G#",
    "Ab": "G#",
    "A": "A",
    "A#": "A#",
    "Bb": "A#",
    "B": "B",
    "Cb": "B"
]

func canonicalPitchClass(for note: String) -> String {
    canonicalPitchClasses[note] ?? note
}

func canonicalChordIdentity(for chord: String) -> String {
    if chord.hasSuffix("dim") {
        let root = String(chord.dropLast(3))
        return "\(canonicalPitchClass(for: root))dim"
    }

    if chord.hasSuffix("m") {
        let root = String(chord.dropLast())
        return "\(canonicalPitchClass(for: root))m"
    }

    return canonicalPitchClass(for: chord)
}

func sharedItems(
    source: [String],
    other: [String],
    normalize: (String) -> String
) -> [String] {
    let sourceKeys = Set(source.map(normalize))
    var seen = Set<String>()

    return other.filter { item in
        let key = normalize(item)
        guard sourceKeys.contains(key) else { return false }
        return seen.insert(key).inserted
    }
}
