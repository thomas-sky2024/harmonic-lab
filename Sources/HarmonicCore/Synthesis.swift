import Foundation

public enum Instrument: String, CaseIterable, Codable, Identifiable, Sendable {
    case softKeys = "Soft keys", warmPad = "Warm pad", glassPluck = "Glass pluck"
    public var id: String { rawValue }
}
public enum Synthesizer {
    public static let sampleRate = 22050
    public static func render(events: [NoteEvent], tempo: Double, beats: Double, instrument: Instrument) -> [Float] {
        let secondsPerBeat = 60 / max(40, tempo)
        let duration = max(0.2, beats * secondsPerBeat) + 0.55
        var samples = [Float](repeating: 0, count: Int(duration * Double(sampleRate)))
        for event in events {
            let frequency = 440 * pow(2, Double(event.note - 69) / 12)
            let start = Int(event.start * secondsPerBeat * Double(sampleRate))
            let held = event.duration * secondsPerBeat
            let tail = instrument == .warmPad ? 0.5 : 0.3
            let count = Int((held + tail) * Double(sampleRate))
            let step = 2 * Double.pi * frequency / Double(sampleRate)
            for i in 0..<count {
                let index = start + i
                if index < 0 || index >= samples.count { continue }
                let time = Double(i) / Double(sampleRate)
                let release = time > held ? max(0, 1 - (time - held) / tail) : 1
                let attack = min(1, time / (instrument == .warmPad ? 0.12 : 0.008))
                let decay: Double
                let wave: Double
                let phase = Double(i) * step
                switch instrument {
                case .softKeys:
                    decay = exp(-time * 1.7) * 0.75 + 0.25
                    wave = sin(phase) + 0.28 * sin(phase * 2) * exp(-time * 3) + 0.12 * sin(phase * 3) * exp(-time * 4)
                case .warmPad:
                    decay = 0.85
                    wave = sin(phase) + 0.25 * sin(phase * 1.003) + 0.12 * sin(phase * 2)
                case .glassPluck:
                    decay = exp(-time * 3.5)
                    wave = sin(phase) + 0.35 * sin(phase * 2.001) + 0.18 * sin(phase * 4)
                }
                samples[index] += Float(wave * attack * decay * release * Double(event.velocity) / 127 * 0.12)
            }
        }
        return samples.map { max(-0.95, min(0.95, $0)) }
    }
    public static func wav(samples: [Float]) -> Data {
        var bytes: [UInt8] = []
        func u16(_ n: UInt16) { bytes += [UInt8(n & 255), UInt8(n >> 8)] }
        func u32(_ n: UInt32) { bytes += [UInt8(n & 255),UInt8((n >> 8) & 255),UInt8((n >> 16) & 255),UInt8(n >> 24)] }
        bytes += Array("RIFF".utf8); u32(UInt32(36 + samples.count * 2)); bytes += Array("WAVEfmt ".utf8)
        u32(16); u16(1); u16(1); u32(UInt32(sampleRate)); u32(UInt32(sampleRate * 2)); u16(2); u16(16)
        bytes += Array("data".utf8); u32(UInt32(samples.count * 2))
        bytes.reserveCapacity(44 + samples.count * 2)
        for sample in samples {
            let value = UInt16(bitPattern: Int16(max(-1, min(1, sample)) * 32767)); u16(value)
        }
        return Data(bytes)
    }
}
