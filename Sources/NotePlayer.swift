import AppKit
import AVFoundation

@MainActor
final class NotePlayer {
    private var players: [AVAudioPlayer] = []
    /// Each group sounds together, `spacing` seconds after the previous group.
    func play(_ groups: [[Int]], spacing: Double = 0) {
        let groups = groups.filter { !$0.isEmpty }
        guard !groups.isEmpty else { return }
        let singleNote = groups.count == 1 && groups[0].count == 1
        do {
            let player = try AVAudioPlayer(data: Self.wave(groups, spacing: spacing))
            // Single notes ring together like a keyboard. Chords and phrases fade out what came before.
            players.removeAll { !$0.isPlaying }
            if !singleNote { players.forEach { $0.setVolume(0, fadeDuration: 0.05) } }
            player.play()
            players.append(player)
        }
        catch { AppLogger.lifecycle.error("Audio playback failed: \(error.localizedDescription, privacy: .public)"); NSSound.beep() }
    }
    static func wave(_ groups: [[Int]], spacing: Double) -> Data {
        let rate = 44100.0
        let length = 1.2
        let count = Int((length + spacing * Double(groups.count - 1)) * rate)
        var mix = [Double](repeating: 0, count: count)
        for (index, group) in groups.enumerated() {
            let start = Int(Double(index) * spacing * rate)
            for midi in group {
                let frequency = 440 * pow(2, Double(midi - 69) / 12)
                for i in 0..<min(Int(length * rate), count - start) {
                    let elapsed = Double(i) / rate
                    let envelope = min(1, elapsed / 0.008) * exp(-elapsed * 3) * min(1, (length - elapsed) / 0.06)
                    mix[start + i] += (sin(2 * .pi * frequency * elapsed) + 0.18 * sin(4 * .pi * frequency * elapsed)) * envelope
                }
            }
        }
        let singleNote = groups.count == 1 && groups[0].count == 1
        let gain = 0.45 / (singleNote ? 1 : 3)
        let samples = mix.map { Int16(max(-1, min(1, $0 * gain)) * 32767) }
        var data = Data()
        func bytes<T: FixedWidthInteger>(_ value: T) { var little = value.littleEndian; withUnsafeBytes(of: &little) { data.append(contentsOf: $0) } }
        data.append(contentsOf: "RIFF".utf8); bytes(UInt32(36 + count * 2))
        data.append(contentsOf: "WAVEfmt ".utf8); bytes(UInt32(16)); bytes(UInt16(1)); bytes(UInt16(1))
        bytes(UInt32(rate)); bytes(UInt32(rate * 2)); bytes(UInt16(2)); bytes(UInt16(16))
        data.append(contentsOf: "data".utf8); bytes(UInt32(count * 2))
        samples.withUnsafeBytes { data.append(contentsOf: $0) }
        return data
    }
}
