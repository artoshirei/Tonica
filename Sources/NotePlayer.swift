import AppKit
import AVFoundation

@MainActor
final class NotePlayer {
    private var player: AVAudioPlayer?
    func play(_ notes: [Int], arpeggio: Bool = false) {
        guard !notes.isEmpty else { return }
        let rate = 44100
        let spacing = arpeggio ? 0.25 : 0
        let duration = 1.2 + spacing * Double(notes.count - 1)
        let count = Int(duration * Double(rate))
        var samples = [Int16](repeating: 0, count: count)
        for i in 0..<count {
            let t = Double(i) / Double(rate)
            var sample = 0.0
            for (index, midi) in notes.enumerated() {
                let elapsed = t - Double(index) * spacing
                guard elapsed >= 0, elapsed < 1.2 else { continue }
                let frequency = 440 * pow(2, Double(midi - 69) / 12)
                let envelope = min(1, elapsed / 0.008) * exp(-elapsed * 3) * min(1, (1.2 - elapsed) / 0.06)
                sample += (sin(2 * .pi * frequency * elapsed) + 0.18 * sin(4 * .pi * frequency * elapsed)) * envelope
            }
            samples[i] = Int16(max(-1, min(1, sample * 0.45 / Double(arpeggio ? 3 : notes.count))) * 32767)
        }
        var data = Data()
        func bytes<T: FixedWidthInteger>(_ value: T) { var little = value.littleEndian; withUnsafeBytes(of: &little) { data.append(contentsOf: $0) } }
        data.append(contentsOf: "RIFF".utf8); bytes(UInt32(36 + count * 2))
        data.append(contentsOf: "WAVEfmt ".utf8); bytes(UInt32(16)); bytes(UInt16(1)); bytes(UInt16(1))
        bytes(UInt32(rate)); bytes(UInt32(rate * 2)); bytes(UInt16(2)); bytes(UInt16(16))
        data.append(contentsOf: "data".utf8); bytes(UInt32(count * 2))
        samples.withUnsafeBytes { data.append(contentsOf: $0) }
        do { player = try AVAudioPlayer(data: data); player?.play() }
        catch { AppLogger.lifecycle.error("Audio playback failed: \(error.localizedDescription, privacy: .public)"); NSSound.beep() }
    }
}
