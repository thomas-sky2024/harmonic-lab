import XCTest
@testable import HarmonicCore

final class MusicTests: XCTestCase {
    func testCMajorAndAminorDiatonicTriads() {
        XCTAssertEqual(Scale(root: 0,kind: .major).chords().map(\.name),["C","Dm","Em","F","G","Am","Bdim"])
        XCTAssertEqual(Scale(root: 9,kind: .naturalMinor).chords().map(\.name),["Am","Bdim","C","Dm","Em","F","G"])
    }
    func testAllDiatonicChordsRemainInsideTheirScale() {
        for root in 0..<12 {
            for kind in ScaleKind.allCases {
                let scale = Scale(root: root,kind: kind)
                for seventh in [false,true] {
                    for chord in scale.chords(sevenths: seventh) { XCTAssertTrue(chord.pitchClasses.isSubset(of: scale.pitchClasses),"\(scale.name): \(chord.name)") }
                }
            }
        }
    }
    func testMajorSeventhsAndHarmonicMinor() {
        XCTAssertEqual(Scale(root: 0,kind: .major).chords(sevenths: true).map(\.name),["Cmaj7","Dm7","Em7","Fmaj7","G7","Am7","Bm7♭5"])
        XCTAssertEqual(Scale(root: 9,kind: .harmonicMinor).chords(sevenths: true)[2].quality,.augmentedMajor7)
    }
    func testTranspositionCrossesOctaveWithoutChangingIntervals() {
        let chord = Chord(root: 11,quality: .minor7,octave: 3)
        XCTAssertEqual(chord.transposed(1).notes,chord.notes.map { $0+1 })
        XCTAssertEqual(chord.transposed(-12).notes,chord.notes.map { $0-12 })
    }
    func testInversionAndRomanNumerals() {
        XCTAssertEqual(Chord(root: 0,inversion: 1).notes,[52,55,60])
        XCTAssertEqual(Scale(root: 0,kind: .major).roman(for: Chord(root: 9,quality: .minor)),"vi")
    }
    func testChordDetectionAndSlashBass() {
        XCTAssertEqual(Theory.detect(notes: [60,64,67]).first?.chord.name,"C")
        XCTAssertEqual(Theory.detect(notes: [64,67,72]).first?.name,"C/E")
        XCTAssertEqual(Theory.detect(notes: [57,60,64,67]).first?.chord.name,"Am7")
        XCTAssertTrue(Theory.detect(notes: [60,72]).isEmpty)
    }
    func testAllTriadAndSeventhRootsDetectWithRootInBass() {
        for root in 0..<12 { for quality in [ChordQuality.major,.minor,.major7,.minor7,.dominant7,.halfDiminished7] {
            let chord = Chord(root: root,quality: quality)
            XCTAssertEqual(Theory.detect(notes: chord.notes).first?.chord,chord,"\(chord.name)")
        }}
    }
    func testParseNotesAndMidiNumbers() { XCTAssertEqual(Music.parse("C4 E4 G4, Bb3 72"),[60,64,67,58,72]); XCTAssertTrue(Music.parse("H4 999").isEmpty) }
    func testVoiceLeadingPreservesPitchClassesAndReducesMotion() {
        let before = [48,52,55]; let original = [57,60,64]
        let result = Theory.voiceLed(original,after: before)
        XCTAssertEqual(Set(result.map(Music.pc)),Set(original.map(Music.pc)))
        XCTAssertLessThanOrEqual(zip(result,before).reduce(0) { $0+abs($1.0-$1.1) },zip(original,before).reduce(0) { $0+abs($1.0-$1.1) })
    }
    func testSessionRoundTripAndValidation() throws {
        let project = Project.demo; let data = try JSONEncoder().encode(project)
        XCTAssertEqual(try JSONDecoder().decode(Project.self,from: data).validated(),project)
        var broken = project; broken.clips[0].beats = -1; XCTAssertThrowsError(try broken.validated())
        broken = project; broken.tempo = .infinity; XCTAssertThrowsError(try broken.validated())
        broken = project; broken.clips[0].chord.inversion = 4; XCTAssertThrowsError(try broken.validated())
        broken = project; broken.clips[0].chord.octave = 7; XCTAssertThrowsError(try broken.validated())
    }
    func testMidiExportRoundTrip() throws {
        var project = Project.demo; project.voiceLeading = false
        let data = MIDIFile.encode(project: project)
        XCTAssertEqual(String(data: data.prefix(4),encoding: .ascii),"MThd")
        let imported = try MIDIImporter.decode(data)
        XCTAssertEqual(imported.clips.map { $0.chord.pitchClasses },project.clips.map { $0.chord.pitchClasses })
        XCTAssertEqual(imported.clips.dropLast().map(\.beats),[4,4,4])
        XCTAssertEqual(imported.tempo,project.tempo,accuracy: 0.001)
    }
    func testMalformedMIDIIsRejected() { XCTAssertThrowsError(try MIDIImporter.decode(Data("bad".utf8))); XCTAssertThrowsError(try MIDIImporter.decode(MIDIFile.encode(project: .demo).prefix(30))) }
    func testVariableLengthMidiEncoding() { XCTAssertEqual(MIDIFile.variableLength(127),[127]); XCTAssertEqual(MIDIFile.variableLength(128),[0x81,0]); XCTAssertEqual(MIDIFile.variableLength(0x3fff),[0xff,0x7f]) }
    func testRunningStatusRealtimeAndSplitPackets() {
        var parser = MIDIStreamDecoder()
        XCTAssertTrue(parser.feed([0x90,60]).isEmpty)
        let first = parser.feed([0xf8,100,64,90]); XCTAssertEqual(first.map(\.0),[60,64]); XCTAssertTrue(first.allSatisfy(\.1))
        let off = parser.feed([60,0,0x80,64,64]); XCTAssertEqual(off.map(\.0),[60,64]); XCTAssertTrue(off.allSatisfy { !$0.1 })
    }
    func testMotionEventsStayInClipsAndNotesHaveOffs() {
        for motion in Motion.allCases {
            var p = Project.demo;p.motion = motion
            let events = Arrangement.events(for: p)
            XCTAssertFalse(events.isEmpty); XCTAssertTrue(events.allSatisfy { $0.start >= 0 && $0.duration > 0 && $0.start+$0.duration <= p.totalBeats })
        }
    }
    func testSynthProducesFiniteBoundedAudioAndWav() {
        let samples = Synthesizer.render(events: [NoteEvent(note: 60,start: 0,duration: 1)],tempo: 120,beats: 1,instrument: .softKeys)
        XCTAssertTrue(samples.allSatisfy { $0.isFinite && abs($0) <= 0.95 }); XCTAssertGreaterThan(samples.map { abs($0) }.max()!,0.01)
        let wav = Synthesizer.wav(samples: samples)
        XCTAssertEqual(wav.count,44+samples.count*2); XCTAssertEqual(String(data: wav.prefix(4),encoding: .ascii),"RIFF")
    }
    func testAudioDetectsSyntheticMajorTriad() throws {
        let chord = Chord(root: 0)
        let samples = Synthesizer.render(events: chord.notes.map { NoteEvent(note: $0,start: 0,duration: 4) },tempo: 120,beats: 4,instrument: .softKeys)
        let result = try AudioChordAnalyzer.analyze(samples: samples,sampleRate: Double(Synthesizer.sampleRate))
        XCTAssertTrue(result.contains { $0.chord.root == 0 && $0.chord.quality == .major })
    }
    func testAudioSilenceRejected() { XCTAssertThrowsError(try AudioChordAnalyzer.analyze(samples: Array(repeating: 0,count: 22050),sampleRate: 22050)) }
}
