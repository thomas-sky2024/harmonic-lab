import Foundation

public enum Music {
    public static let sharpNames = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
    public static let flatNames = ["C", "D♭", "D", "E♭", "E", "F", "G♭", "G", "A♭", "A", "B♭", "B"]
    public static func pc(_ n: Int) -> Int { (n % 12 + 12) % 12 }
    public static func note(_ n: Int, flats: Bool = false) -> String { (flats ? flatNames : sharpNames)[pc(n)] }
    public static func label(_ midi: Int) -> String { "\(note(midi))\(midi / 12 - 1)" }
    public static func parse(_ text: String) -> [Int] {
        let names = ["C": 0, "C#": 1, "DB": 1, "D": 2, "D#": 3, "EB": 3, "E": 4, "FB": 4, "E#": 5, "F": 5, "F#": 6, "GB": 6, "G": 7, "G#": 8, "AB": 8, "A": 9, "A#": 10, "BB": 10, "B": 11, "CB": 11, "B#": 0]
        return text.uppercased().replacingOccurrences(of: "♯", with: "#").replacingOccurrences(of: "♭", with: "B")
            .split(whereSeparator: { $0.isWhitespace || $0 == "," || $0 == ";" })
            .compactMap { token in
                if let midi = Int(token), (0...127).contains(midi) { return midi }
                let s = String(token); let pitch = String(s.prefix(while: { !$0.isNumber && $0 != "-" }))
                guard let p = names[pitch] else { return nil }
                let octave = Int(s.dropFirst(pitch.count)) ?? 4
                let value = (octave + 1) * 12 + p
                return (0...127).contains(value) ? value : nil
            }
    }
}

public enum ScaleKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case major = "Major", naturalMinor = "Natural minor", dorian = "Dorian", phrygian = "Phrygian"
    case lydian = "Lydian", mixolydian = "Mixolydian", locrian = "Locrian"
    case harmonicMinor = "Harmonic minor", melodicMinor = "Melodic minor"
    case majorPentatonic = "Major pentatonic", minorPentatonic = "Minor pentatonic", blues = "Blues"
    public var id: String { rawValue }
    public var intervals: [Int] {
        switch self {
        case .major: return [0,2,4,5,7,9,11]
        case .naturalMinor: return [0,2,3,5,7,8,10]
        case .dorian: return [0,2,3,5,7,9,10]
        case .phrygian: return [0,1,3,5,7,8,10]
        case .lydian: return [0,2,4,6,7,9,11]
        case .mixolydian: return [0,2,4,5,7,9,10]
        case .locrian: return [0,1,3,5,6,8,10]
        case .harmonicMinor: return [0,2,3,5,7,8,11]
        case .melodicMinor: return [0,2,3,5,7,9,11]
        case .majorPentatonic: return [0,2,4,7,9]
        case .minorPentatonic: return [0,3,5,7,10]
        case .blues: return [0,3,5,6,7,10]
        }
    }
    public var character: String {
        switch self {
        case .major: return "Bright · open · resolved"
        case .naturalMinor: return "Reflective · intimate · cinematic"
        case .dorian: return "Soulful · understated · hopeful"
        case .phrygian: return "Dark · dramatic · Spanish"
        case .lydian: return "Floating · dreamlike · expansive"
        case .mixolydian: return "Bluesy · grounded · warm"
        case .locrian: return "Unstable · tense · experimental"
        case .harmonicMinor: return "Dramatic · classical · mysterious"
        case .melodicMinor: return "Jazz · fluid · sophisticated"
        case .majorPentatonic: return "Simple · uplifting · folk"
        case .minorPentatonic: return "Blues · expressive · direct"
        case .blues: return "Gritty · soulful · expressive"
        }
    }
}

public enum ChordQuality: String, Codable, CaseIterable, Identifiable, Sendable {
    case major, minor, diminished, augmented, sus2, sus4, major7, minor7, dominant7, halfDiminished7, diminished7, minorMajor7, augmentedMajor7, major6, minor6, add9, minorAdd9, dominant9, major9, minor9
    public var id: String { rawValue }
    public var suffix: String {
        switch self {
        case .major: return ""
        case .minor: return "m"
        case .diminished: return "dim"
        case .augmented: return "+"
        case .sus2: return "sus2"
        case .sus4: return "sus4"
        case .major7: return "maj7"
        case .minor7: return "m7"
        case .dominant7: return "7"
        case .halfDiminished7: return "m7♭5"
        case .diminished7: return "dim7"
        case .minorMajor7: return "m(maj7)"
        case .augmentedMajor7: return "+maj7"
        case .major6: return "6"
        case .minor6: return "m6"
        case .add9: return "add9"
        case .minorAdd9: return "m(add9)"
        case .dominant9: return "9"
        case .major9: return "maj9"
        case .minor9: return "m9"
        }
    }
    public var intervals: [Int] {
        switch self {
        case .major: return [0,4,7]
        case .minor: return [0,3,7]
        case .diminished: return [0,3,6]
        case .augmented: return [0,4,8]
        case .sus2: return [0,2,7]
        case .sus4: return [0,5,7]
        case .major7: return [0,4,7,11]
        case .minor7: return [0,3,7,10]
        case .dominant7: return [0,4,7,10]
        case .halfDiminished7: return [0,3,6,10]
        case .diminished7: return [0,3,6,9]
        case .minorMajor7: return [0,3,7,11]
        case .augmentedMajor7: return [0,4,8,11]
        case .major6: return [0,4,7,9]
        case .minor6: return [0,3,7,9]
        case .add9: return [0,4,7,14]
        case .minorAdd9: return [0,3,7,14]
        case .dominant9: return [0,4,7,10,14]
        case .major9: return [0,4,7,11,14]
        case .minor9: return [0,3,7,10,14]
        }
    }
}

public struct Chord: Codable, Hashable, Sendable {
    public var root: Int
    public var quality: ChordQuality
    public var inversion: Int
    public var octave: Int
    public init(root: Int, quality: ChordQuality = .major, inversion: Int = 0, octave: Int = 3) {
        self.root = Music.pc(root); self.quality = quality; self.inversion = inversion; self.octave = octave
    }
    public var name: String { Music.note(root) + quality.suffix }
    public var pitchClasses: Set<Int> { Set(quality.intervals.map { Music.pc(root + $0) }) }
    public var notes: [Int] {
        var result = quality.intervals.map { (octave + 1) * 12 + root + $0 }
        for _ in 0..<max(0, min(inversion, result.count - 1)) { result.append(result.removeFirst() + 12) }
        return result.map { min(127, max(0, $0)) }
    }
    public func transposed(_ semitones: Int) -> Chord {
        let absolute = (octave + 1) * 12 + root + semitones
        return Chord(root: Music.pc(absolute), quality: quality, inversion: inversion, octave: Int(floor(Double(absolute) / 12)) - 1)
    }
}

public struct Scale: Hashable, Sendable {
    public var root: Int
    public var kind: ScaleKind
    public init(root: Int, kind: ScaleKind) { self.root = Music.pc(root); self.kind = kind }
    public var name: String { "\(Music.note(root)) \(kind.rawValue)" }
    public var pitchClasses: Set<Int> { Set(kind.intervals.map { Music.pc(root + $0) }) }
    public func chords(sevenths: Bool = false, octave: Int = 3) -> [Chord] {
        // Diatonic tertian harmony is defined here for seven-note scales.
        guard kind.intervals.count == 7 else {
            return (0..<12).flatMap { p in [ChordQuality.major, .minor, .sus2, .sus4].compactMap { q -> Chord? in
                let c = Chord(root: p, quality: q, octave: octave)
                return c.pitchClasses.isSubset(of: pitchClasses) ? c : nil
            }}
        }
        let steps = kind.intervals
        return (0..<7).map { degree in
            let base = steps[degree]
            let intervals = (0..<(sevenths ? 4 : 3)).map { i -> Int in
                let index = degree + i * 2
                return steps[index % 7] + 12 * (index / 7) - base
            }
            let quality = ChordQuality.allCases.first { $0.intervals == intervals } ?? .major
            return Chord(root: root + base, quality: quality, octave: octave)
        }
    }
    public func roman(for chord: Chord) -> String {
        guard let degree = kind.intervals.firstIndex(of: Music.pc(chord.root - root)), degree < 7 else { return "—" }
        let roman = ["I","II","III","IV","V","VI","VII"][degree]
        let minor = [.minor, .minor7, .minor9, .minorAdd9, .minor6, .minorMajor7, .diminished, .halfDiminished7, .diminished7].contains(chord.quality)
        return (minor ? roman.lowercased() : roman) + (chord.quality == .diminished ? "°" : "")
    }
}

public struct ChordMatch: Identifiable, Sendable {
    public let chord: Chord
    public let bass: Int
    public let score: Double
    public var id: String { "\(chord.root)-\(chord.quality.rawValue)" }
    public var name: String { chord.name + (Music.pc(bass) == chord.root ? "" : "/" + Music.note(bass)) }
}

public enum Theory {
    public static func detect(notes: [Int]) -> [ChordMatch] {
        guard Set(notes.map(Music.pc)).count >= 2, let bass = notes.min() else { return [] }
        let pcs = Set(notes.map(Music.pc))
        var matches: [ChordMatch] = []
        for root in 0..<12 {
            for quality in ChordQuality.allCases {
                let chord = Chord(root: root, quality: quality)
                let target = chord.pitchClasses
                let missing = target.subtracting(pcs).count
                let extra = pcs.subtracting(target).count
                let score = 1.0 - Double(missing * 2 + extra) / Double(max(target.count, pcs.count) * 2)
                if score >= 0.7 { matches.append(ChordMatch(chord: chord, bass: bass, score: score)) }
            }
        }
        return matches.sorted {
            if abs($0.score - $1.score) > 0.0001 { return $0.score > $1.score }
            if ($0.chord.root == Music.pc(bass)) != ($1.chord.root == Music.pc(bass)) { return $0.chord.root == Music.pc(bass) }
            if $0.chord.quality.intervals.count != $1.chord.quality.intervals.count { return $0.chord.quality.intervals.count < $1.chord.quality.intervals.count }
            return $0.id < $1.id
        }
    }
    public static func matchingScales(notes: [Int]) -> [(Scale, Double)] {
        let pcs = Set(notes.map(Music.pc)); guard !pcs.isEmpty else { return [] }
        return (0..<12).flatMap { root in ScaleKind.allCases.map { kind -> (Scale, Double) in
            let scale = Scale(root: root, kind: kind)
            return (scale, Double(pcs.intersection(scale.pitchClasses).count) / Double(pcs.count))
        }}.sorted {
            if $0.1 != $1.1 { return $0.1 > $1.1 }
            if $0.0.root != $1.0.root { return $0.0.root < $1.0.root }
            return ScaleKind.allCases.firstIndex(of: $0.0.kind)! < ScaleKind.allCases.firstIndex(of: $1.0.kind)!
        }
    }
    public static func voiceLed(_ notes: [Int], after previous: [Int]) -> [Int] {
        guard !previous.isEmpty else { return notes }
        var candidates: [[Int]] = []
        for shift in [-12, 0, 12] {
            var voicing = notes.map { $0 + shift }
            for _ in 0..<notes.count {
                if voicing.allSatisfy({ (36...88).contains($0) }) { candidates.append(voicing) }
                voicing.append(voicing.removeFirst() + 12)
            }
        }
        func distance(_ a: [Int]) -> Int { a.enumerated().reduce(0) { $0 + abs($1.element - previous[min($1.offset, previous.count - 1)]) } }
        return candidates.min { distance($0) < distance($1) } ?? notes
    }
}
