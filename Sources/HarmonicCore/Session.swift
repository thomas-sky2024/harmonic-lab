import Foundation

public struct Clip: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var chord: Chord
    public var beats: Double
    public init(chord: Chord, beats: Double = 4, id: UUID = UUID()) { self.chord = chord; self.beats = beats; self.id = id }
}
public enum Motion: String, Codable, CaseIterable, Identifiable, Sendable {
    case block = "Block", strum = "Strum", arpeggio = "Arpeggio"
    public var id: String { rawValue }
}
public struct Project: Codable, Equatable, Sendable {
    public var version = 1
    public var name: String
    public var root: Int
    public var scale: ScaleKind
    public var tempo: Double
    public var clips: [Clip]
    public var motion: Motion
    public var voiceLeading: Bool
    public var octave: Int
    public init(name: String = "Untitled session", root: Int = 0, scale: ScaleKind = .major, tempo: Double = 108, clips: [Clip] = [], motion: Motion = .block, voiceLeading: Bool = true, octave: Int = 3) {
        self.name = name; self.root = root; self.scale = scale; self.tempo = tempo; self.clips = clips; self.motion = motion; self.voiceLeading = voiceLeading; self.octave = octave
    }
    public func validated() throws -> Project {
        guard version == 1, (0..<12).contains(root), tempo.isFinite, (40...240).contains(tempo), (1...5).contains(octave), clips.count <= 128,
              Set(clips.map(\.id)).count == clips.count,
              clips.allSatisfy({ $0.beats.isFinite && (0.5...16).contains($0.beats) && (0..<12).contains($0.chord.root) && (0..<$0.chord.quality.intervals.count).contains($0.chord.inversion) && (1...5).contains($0.chord.octave) }) else { throw SessionError.invalid }
        return self
    }
    public var totalBeats: Double { clips.reduce(0) { $0 + $1.beats } }
    public static var demo: Project {
        Project(name: "A little room to wander", clips: [
            Clip(chord: Chord(root: 0, quality: .major7)), Clip(chord: Chord(root: 9, quality: .minor7)),
            Clip(chord: Chord(root: 5, quality: .major7)), Clip(chord: Chord(root: 7, quality: .dominant7))
        ])
    }
}
public enum SessionError: LocalizedError { case invalid; public var errorDescription: String? { "This session contains unsupported or invalid values." } }

public struct NoteEvent: Equatable, Sendable {
    public var note: Int
    public var start: Double
    public var duration: Double
    public var velocity: Int
    public init(note: Int, start: Double, duration: Double, velocity: Int = 88) { self.note = note; self.start = start; self.duration = duration; self.velocity = velocity }
}
public enum Arrangement {
    public static func events(for project: Project) -> [NoteEvent] {
        var events: [NoteEvent] = []; var position = 0.0; var previous: [Int] = []
        for clip in project.clips {
            let raw = clip.chord.notes
            let notes = project.voiceLeading ? Theory.voiceLed(raw, after: previous) : raw
            previous = notes
            switch project.motion {
            case .block, .strum:
                for (index, note) in notes.enumerated() {
                    let offset = project.motion == .strum ? Double(index) * 0.06 : 0
                    events.append(NoteEvent(note: note, start: position + offset, duration: max(0.1, clip.beats * 0.92 - offset), velocity: 86 - index * 3))
                }
            case .arpeggio:
                for step in 0..<Int(ceil(clip.beats * 2)) {
                    let offset = Double(step) * 0.5
                    events.append(NoteEvent(note: notes[step % notes.count], start: position + offset, duration: min(0.43, clip.beats - offset), velocity: step % 2 == 0 ? 92 : 76))
                }
            }
            position += clip.beats
        }
        return events
    }
}

public enum MIDIFile {
    public static func variableLength(_ input: Int) -> [UInt8] {
        var value = max(0, min(input, 0x0fffffff)); var bytes = [UInt8(value & 0x7f)]; value >>= 7
        while value > 0 { bytes.insert(UInt8(value & 0x7f) | 0x80, at: 0); value >>= 7 }
        return bytes
    }
    public static func encode(project: Project) -> Data {
        let ppq = 480
        let tempo = Int(60_000_000 / max(40, min(240, project.tempo)))
        var track: [UInt8] = [0,0xff,0x51,3,UInt8((tempo >> 16) & 255),UInt8((tempo >> 8) & 255),UInt8(tempo & 255),0,0xff,0x58,4,4,2,24,8]
        let name = Array(project.name.utf8.prefix(120)); track += [0,0xff,3] + variableLength(name.count) + name
        struct Event { let tick: Int; let off: Bool; let note: Int; let velocity: Int }
        var events: [Event] = []
        for e in Arrangement.events(for: project) {
            let start = Int((e.start * Double(ppq)).rounded())
            let end = Int(((e.start + e.duration) * Double(ppq)).rounded())
            events.append(Event(tick: start,off: false,note: e.note,velocity: e.velocity))
            events.append(Event(tick: end,off: true,note: e.note,velocity: 0))
        }
        events.sort { a,b in
            if a.tick != b.tick { return a.tick < b.tick }
            if a.off != b.off { return a.off }
            return a.note < b.note
        }
        var last = 0
        for event in events { track += variableLength(event.tick - last) + [event.off ? 0x80 : 0x90, UInt8(clamping: event.note), UInt8(clamping: event.velocity)]; last = event.tick }
        let end = max(last, Int(project.totalBeats * Double(ppq)))
        track += variableLength(end - last) + [0xff,0x2f,0]
        let size = UInt32(track.count)
        return Data([0x4d,0x54,0x68,0x64,0,0,0,6,0,0,0,1,1,0xe0,0x4d,0x54,0x72,0x6b,
                     UInt8((size >> 24) & 255),UInt8((size >> 16) & 255),UInt8((size >> 8) & 255),UInt8(size & 255)] + track)
    }
}
