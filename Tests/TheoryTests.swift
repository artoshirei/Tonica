import Foundation

@main
struct TheoryTests {
    @MainActor static func main() {
        let majorIntervals = [0, 2, 4, 5, 7, 9, 11]
        let minorIntervals = [0, 2, 3, 5, 7, 8, 10]
        let majorQualities = [[0,4,7], [0,3,7], [0,3,7], [0,4,7], [0,4,7], [0,3,7], [0,3,6]]
        let minorQualities = [[0,3,7], [0,3,6], [0,4,7], [0,3,7], [0,3,7], [0,4,7], [0,4,7]]
        func intervals(_ notes: [String]) -> [Int] {
            let root = midiPitchClass(notes[0])
            return notes.map { (midiPitchClass($0) - root + 12) % 12 }
        }
        for slice in CircleSlice.all {
            precondition(intervals(slice.scaleNotes) == majorIntervals, slice.majorLabel)
            precondition(intervals(slice.minorScaleNotes) == minorIntervals, slice.minorLabel)
            for (scale, qualities) in [(slice.scaleNotes, majorQualities), (slice.minorScaleNotes, minorQualities)] {
                for degree in 0..<7 {
                    let notes = [0, 2, 4].map { scale[(degree + $0) % 7] }
                    precondition(intervals(notes) == qualities[degree], "Invalid triad in \(slice.majorLabel)")
                    let midi = ascendingMIDINotes(notes)
                    precondition(zip(midi, midi.dropFirst()).allSatisfy { $0 < $1 })
                }
                let ascendingScale = ascendingMIDINotes(scale + [scale[0]])
                precondition(ascendingScale.last! - ascendingScale.first! == 12)
            }
        }
        precondition(midiPitchClass("E#") == midiPitchClass("F"))
        precondition(midiPitchClass("Gb") == midiPitchClass("F#"))
        precondition(sharedItems(source: ["F#", "A#"], other: ["Gb", "Bb", "A#"], normalize: canonicalPitchClass) == ["Gb", "Bb"])
        for index in 0..<12 {
            let a = CircleSlice.all[index], b = CircleSlice.all[(index + 1) % 12]
            precondition(a.sharedScaleNotes(with: b).count == 6)
        }
        print("Passed: 24 scales, 168 triads, ascending playback, enharmonic matching, and all neighboring keys.")
    }
}
