import Foundation

public struct MIDIImportResult: Sendable {
    public var tempo: Double
    public var clips: [Clip]
    public var noteCount: Int
}
public enum MIDIImportError: LocalizedError {
    case malformed, unsupportedTiming, noChords, tooLarge
    public var errorDescription: String? {
        switch self {
        case .malformed: return "This MIDI file is truncated or malformed."
        case .unsupportedTiming: return "SMPTE-timed and asynchronous type-2 MIDI files are not supported. Use a standard type-0 or type-1 file."
        case .noChords: return "No simultaneous chord notes were found in this MIDI file. Try a polyphonic chord track."
        case .tooLarge: return "Choose a MIDI file smaller than 5 MB."
        }
    }
}
public enum MIDIImporter {
    public static func decode(_ data: Data) throws -> MIDIImportResult {
        guard data.count <= 5_000_000 else { throw MIDIImportError.tooLarge }
        let bytes = [UInt8](data); var cursor = 0
        func read(_ count: Int) throws -> [UInt8] {
            guard count >= 0, cursor + count <= bytes.count else { throw MIDIImportError.malformed }
            let result = Array(bytes[cursor..<cursor+count]); cursor += count; return result
        }
        func be(_ count: Int) throws -> Int { try read(count).reduce(0) { ($0 << 8) | Int($1) } }
        guard try read(4) == Array("MThd".utf8) else { throw MIDIImportError.malformed }
        let header = try be(4); guard header >= 6,header < 10000 else { throw MIDIImportError.malformed }
        let format = try be(2); let tracks = try be(2); let division = try be(2)
        guard format < 2, division > 0, division < 0x8000 else { throw MIDIImportError.unsupportedTiming }
        _ = try read(header - 6)
        struct Raw { var tick: Int; var note: Int; var down: Bool; var channel: Int }
        var events: [Raw] = []; var tempo = 120.0; var earliestTempo = Int.max; var trackEnd = 0
        for _ in 0..<tracks {
            guard try read(4) == Array("MTrk".utf8) else { throw MIDIImportError.malformed }
            let length = try be(4); let end = cursor + length
            guard end <= bytes.count else { throw MIDIImportError.malformed }
            var tick = 0; var running: UInt8 = 0
            func vlq() throws -> Int {
                var result = 0
                for _ in 0..<4 { guard cursor < end else { throw MIDIImportError.malformed }; let byte = try be(1); result = (result << 7) | (byte & 127); if byte & 128 == 0 { return result } }
                throw MIDIImportError.malformed
            }
            while cursor < end {
                tick += try vlq()
                guard cursor < end else { throw MIDIImportError.malformed }
                var status = bytes[cursor]
                if status & 128 != 0 { cursor += 1 } else { guard running >= 0x80 && running < 0xf0 else { throw MIDIImportError.malformed }; status = running }
                if status == 0xff {
                    let type = try be(1); let count = try vlq(); let payload = try read(count)
                    if type == 0x51, count == 3, tick < earliestTempo {
                        let micros = payload.reduce(0) { ($0 << 8) | Int($1) }
                        if micros > 0 { tempo = 60_000_000 / Double(micros); earliestTempo = tick }
                    }
                } else if status == 0xf0 || status == 0xf7 { let count = try vlq(); _ = try read(count); running = 0 }
                else if status >= 0x80 && status < 0xf0 {
                    running = status
                    let command = status & 0xf0; let count = command == 0xc0 || command == 0xd0 ? 1 : 2
                    let payload = try read(count); guard payload.allSatisfy({ $0 < 128 }) else { throw MIDIImportError.malformed }
                    if (command == 0x90 || command == 0x80),status & 15 != 9 {
                        events.append(Raw(tick: tick,note: Int(payload[0]),down: command == 0x90 && payload[1] > 0,channel: Int(status & 15)))
                    }
                } else { throw MIDIImportError.malformed }
                guard cursor <= end else { throw MIDIImportError.malformed }
            }
            trackEnd = max(trackEnd,tick)
        }
        events.sort { a,b in a.tick == b.tick ? (!a.down && b.down) : a.tick < b.tick }
        // Group near-simultaneous note-ons, including a short strum. Drum channel is excluded.
        var groups: [(Int,Set<Int>)] = []
        let tolerance = max(1,division / 8)
        for event in events where event.down {
            if let last = groups.indices.last, event.tick - groups[last].0 <= tolerance { groups[last].1.insert(event.note) }
            else { groups.append((event.tick,[event.note])) }
        }
        let candidates = Array(groups.lazy.compactMap { tick,notes -> (Int,Chord)? in
            guard notes.count >= 3, let match = Theory.detect(notes: Array(notes)).first, match.score >= 0.8 else { return nil }
            var chord = match.chord; chord.octave = min(5,max(1,(notes.min() ?? 48) / 12 - 1))
            if let bass = notes.min(), let inversion = chord.quality.intervals.firstIndex(where: { Music.pc(chord.root + $0) == Music.pc(bass) }) { chord.inversion = inversion }
            return (tick,chord)
        }.prefix(129))
        guard !candidates.isEmpty else { throw MIDIImportError.noChords }
        let endTick = max(trackEnd,events.map(\.tick).max() ?? division * 4)
        let clips = candidates.prefix(128).enumerated().map { index,item in
            let next = index+1 < candidates.count ? candidates[index+1].0 : max(endTick,item.0 + division)
            let beats = min(16,max(0.5,(Double(next-item.0) / Double(division) * 2).rounded() / 2))
            return Clip(chord: item.1,beats: beats)
        }
        return MIDIImportResult(tempo: min(240,max(40,tempo)),clips: clips,noteCount: events.filter(\.down).count)
    }
}

/// Stateful MIDI 1.0 byte decoder. Realtime bytes may occur inside a message.
public struct MIDIStreamDecoder {
    private var status: UInt8 = 0
    private var pending: [UInt8] = []
    private var sysex = false
    public init() {}
    public mutating func feed(_ bytes: [UInt8]) -> [(Int,Bool)] {
        var result: [(Int,Bool)] = []
        for byte in bytes {
            if byte >= 0xf8 { continue }
            if byte == 0xf0 { sysex = true; status = 0; pending = []; continue }
            if byte == 0xf7 { sysex = false; continue }
            if sysex { continue }
            if byte >= 0x80 { status = byte < 0xf0 ? byte : 0; pending = []; continue }
            guard status != 0 else { continue }
            pending.append(byte)
            let command = status & 0xf0; let count = command == 0xc0 || command == 0xd0 ? 1 : 2
            if pending.count == count {
                if command == 0x80 || command == 0x90 { result.append((Int(pending[0]),command == 0x90 && pending[1] > 0)) }
                pending = []
            }
        }
        return result
    }
}
