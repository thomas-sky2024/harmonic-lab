import Foundation
import Accelerate

public struct AudioChordSegment: Sendable {
    public var start: Double
    public var end: Double
    public var chord: Chord
    public var score: Double
}
public enum AudioAnalysisError: LocalizedError {
    case silence, invalid, unavailable
    public var errorDescription: String? {
        switch self {
        case .silence: return "No stable chord candidates were found. Try a clear, sustained polyphonic instrument recording."
        case .invalid: return "The audio file could not be decoded into a supported PCM format."
        case .unavailable: return "The spectral analysis engine could not be initialized."
        }
    }
}
/// An original, approximate spectral chroma detector. Not Scaler's detection algorithm.
public enum AudioChordAnalyzer {
    public static func analyze(samples: [Float],sampleRate: Double) throws -> [AudioChordSegment] {
        guard sampleRate > 0,sampleRate.isFinite,!samples.isEmpty else { throw AudioAnalysisError.invalid }
        let rate = 22050.0
        let outputCount = Int(Double(samples.count) * rate / sampleRate)
        guard outputCount >= 8192 else { throw AudioAnalysisError.silence }
        let signal: [Float] = (0..<min(outputCount,Int(rate*60))).map { index in
            let source = Double(index) * sampleRate / rate; let i = min(samples.count-1,Int(source)); let j = min(samples.count-1,i+1)
            let fraction = Float(source - Double(i)); return samples[i] * (1-fraction) + samples[j] * fraction
        }
        let size = 8192; let hop = 5512
        guard let setup = vDSP_DFT_zop_CreateSetup(nil,vDSP_Length(size),.FORWARD) else { throw AudioAnalysisError.unavailable }
        defer { vDSP_DFT_DestroySetup(setup) }
        var window = [Float](repeating: 0,count: size); vDSP_hann_window(&window,vDSP_Length(size),Int32(vDSP_HANN_NORM))
        var real = window; let zero = [Float](repeating: 0,count: size)
        var outputReal = zero; var outputImag = zero
        var frames: [(Double,Chord,Double)] = []
        for start in stride(from: 0,through: signal.count-size,by: hop) {
            var energy: Float = 0
            for i in 0..<size { real[i] = signal[start+i] * window[i]; energy += real[i] * real[i] }
            if energy / Float(size) < 0.000002 { continue }
            vDSP_DFT_Execute(setup,real,zero,&outputReal,&outputImag)
            var chroma = [Double](repeating: 0,count: 12); var bassEnergy = [Double](repeating: 0,count: 12)
            for bin in 20..<(size/2) {
                let frequency = Double(bin) * rate / Double(size)
                if frequency > 2000 { break }
                let midi = 69 + 12 * log2(frequency / 440)
                if abs(midi - midi.rounded()) > 0.4 { continue }
                let power = Double(outputReal[bin]*outputReal[bin] + outputImag[bin]*outputImag[bin])
                let pitch = Music.pc(Int(midi.rounded()))
                chroma[pitch] += power / sqrt(frequency)
                if frequency < 420 { bassEnergy[pitch] += power / frequency }
            }
            let sorted = (0..<12).sorted { chroma[$0] > chroma[$1] }
            guard let strongest = sorted.first,chroma[strongest] > 0 else { continue }
            let count = chroma[sorted[3]] > chroma[strongest] * 0.35 ? 4 : 3
            let pitches = Array(sorted.prefix(count))
            let bass = pitches.max { bassEnergy[$0] < bassEnergy[$1] } ?? strongest
            let notes = pitches.map { $0 == bass ? 36 + $0 : 60 + $0 }
            if let match = Theory.detect(notes: notes).first,match.score >= 0.8 {
                frames.append((Double(start)/rate,match.chord,match.score))
            }
        }
        var result: [AudioChordSegment] = []
        var pending: (Double,Chord,Double,Int)?
        let hopSeconds = Double(hop)/rate
        func flush(_ end: Double) {
            guard let value = pending,value.3 >= 2 else { return }
            let segment = AudioChordSegment(start: value.0,end: max(value.0+hopSeconds,end),chord: value.1,score: value.2)
            if let index = result.indices.last,result[index].chord.pitchClasses == segment.chord.pitchClasses,segment.start-result[index].end < 0.6 { result[index].end = segment.end }
            else { result.append(segment) }
        }
        for (time,chord,score) in frames {
            if let previous = pending,previous.1.root == chord.root,previous.1.quality == chord.quality { pending = (previous.0,previous.1,min(score,previous.2),previous.3+1) }
            else { flush(time); pending = (time,chord,score,1) }
        }
        flush(Double(signal.count)/rate)
        guard !result.isEmpty else { throw AudioAnalysisError.silence }
        return result
    }
}
