import XCTest
import AVFoundation
import AudioToolbox
@testable import HarmonicCore

final class ExportIntegrationTests: XCTestCase {
    func testExportsDecodeWithAppleMediaFrameworks() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("harmonic-exports-\(UUID())")
        try FileManager.default.createDirectory(at: folder,withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let project = Project.demo
        let midiURL = folder.appendingPathComponent("demo.mid")
        try MIDIFile.encode(project: project).write(to: midiURL)
        var sequence: MusicSequence?
        XCTAssertEqual(NewMusicSequence(&sequence),noErr)
        guard let sequence else { return XCTFail("No MusicSequence") }
        defer { DisposeMusicSequence(sequence) }
        XCTAssertEqual(MusicSequenceFileLoad(sequence,midiURL as CFURL,.midiType,MusicSequenceLoadFlags()),noErr)
        var trackCount: UInt32 = 0; XCTAssertEqual(MusicSequenceGetTrackCount(sequence,&trackCount),noErr); XCTAssertGreaterThan(trackCount,0)
        var track: MusicTrack?; XCTAssertEqual(MusicSequenceGetIndTrack(sequence,0,&track),noErr)
        if let track {
            var iterator: MusicEventIterator?; NewMusicEventIterator(track,&iterator)
            if let iterator {
                defer { DisposeMusicEventIterator(iterator) }
                var hasEvent: DarwinBoolean = false; var noteCount = 0
                MusicEventIteratorHasCurrentEvent(iterator,&hasEvent)
                while hasEvent.boolValue {
                    var time: MusicTimeStamp = 0; var type: MusicEventType = 0; var data: UnsafeRawPointer?; var size: UInt32 = 0
                    MusicEventIteratorGetEventInfo(iterator,&time,&type,&data,&size)
                    if type == kMusicEventType_MIDINoteMessage { noteCount += 1 }
                    MusicEventIteratorNextEvent(iterator); MusicEventIteratorHasCurrentEvent(iterator,&hasEvent)
                }
                XCTAssertEqual(noteCount,16)
            }
        }
        let samples = Synthesizer.render(events: Arrangement.events(for: project),tempo: project.tempo,beats: project.totalBeats,instrument: .softKeys)
        let wavURL = folder.appendingPathComponent("demo.wav"); try Synthesizer.wav(samples: samples).write(to: wavURL)
        let file = try AVAudioFile(forReading: wavURL)
        XCTAssertEqual(file.processingFormat.sampleRate,22050); XCTAssertEqual(file.processingFormat.channelCount,1)
        XCTAssertEqual(file.length,AVAudioFramePosition(samples.count))
        if let output = ProcessInfo.processInfo.environment["HARMONIC_VERIFY_ARTIFACT_DIR"] {
            let destination = URL(fileURLWithPath: output); try FileManager.default.createDirectory(at: destination,withIntermediateDirectories: true)
            for url in [midiURL,wavURL] { try Data(contentsOf: url).write(to: destination.appendingPathComponent(url.lastPathComponent),options: .atomic) }
            try JSONEncoder().encode(project).write(to: destination.appendingPathComponent("demo.harmonic"),options: .atomic)
        }
    }
}
