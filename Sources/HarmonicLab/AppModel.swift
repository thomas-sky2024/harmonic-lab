import SwiftUI
import AVFoundation
import AppKit
import UniformTypeIdentifiers
import HarmonicCore

@MainActor final class AppModel: ObservableObject {
    @Published var project: Project { didSet { if isPlaying || isRendering { stop() }; persist() } }
    @Published var selectedClip: UUID?
    @Published var selectedChord: Chord = Chord(root: 0, quality: .major7)
    @Published var inputNotes: Set<Int> = []
    @Published var soundingNotes: Set<Int> = []
    @Published var isPlaying = false
    @Published var isRendering = false
    @Published var isAnalyzing = false
    @Published var audioSegments: [AudioChordSegment] = []
    @Published var audioSource = ""
    @Published var playhead = 0.0
    @Published var loop = true
    @Published var sevenths = true
    @Published var instrument: Instrument = .softKeys
    @Published var volume: Double = 0.65 { didSet { player?.volume = Float(volume); preview?.volume = Float(volume) } }
    @Published var midiEnabled = false
    @Published var midiOutput = false
    @Published var midiStatus = "MIDI input off"
    @Published var detectorText = "C4 E4 G4"
    @Published var filter = ""
    @Published var browser = "Scales"
    @Published var inspector = true
    @Published var errorMessage: String?
    @Published var notice = "Ready. Explore a chord or press Space to play."
    @Published var canUndo = false
    @Published var canRedo = false
    private var player: AVAudioPlayer?
    private var preview: AVAudioPlayer?
    private var timer: Timer?
    private var rendering: Task<Void, Never>?
    private var revision = UUID()
    private var analysisRevision = UUID()
    private var history: [Project] = []
    private var future: [Project] = []
    private var midiNotes: Set<Int> = []
    private var midiSchedule: [(Double, Int, Bool, Int)] = []
    private var midiIndex = 0
    private var filePanelOpen = false
    let midi = MIDIService()
    private static var autosaveURL: URL {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("HarmonicLab", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("Last Session.harmonic")
    }
    init() {
        if let data = try? Data(contentsOf: Self.autosaveURL), let saved = try? JSONDecoder().decode(Project.self, from: data).validated() { project = saved }
        else { project = .demo }
        midi.onNote = { [weak self] note, down in self?.receive(note: note, down: down) }
    }
    var scale: Scale { Scale(root: project.root, kind: project.scale) }
    var scaleChords: [Chord] { scale.chords(sevenths: sevenths, octave: project.octave) }
    var matches: [ChordMatch] { Theory.detect(notes: Array(inputNotes)) }
    var scaleMatches: [(Scale, Double)] { Theory.matchingScales(notes: Array(inputNotes)) }
    var activeClip: Clip? { project.clips.first { $0.id == selectedClip } }
    var currentPlayingIndex: Int? {
        guard isPlaying else { return nil }
        var start = 0.0
        for (index, clip) in project.clips.enumerated() { start += clip.beats; if playhead < start { return index } }
        return nil
    }
    var visibleScales: [Scale] {
        ScaleKind.allCases.map { Scale(root: project.root, kind: $0) }.filter { filter.isEmpty || $0.name.localizedCaseInsensitiveContains(filter) || $0.kind.character.localizedCaseInsensitiveContains(filter) }
    }
    func setTempo(_ value: Double) { project.tempo = value.isFinite ? min(240,max(40,value)) : 108 }
    func edit(_ action: (inout Project) -> Void) {
        history.append(project); if history.count > 80 { history.removeFirst() }; future = []
        var next = project; action(&next); project = next
        canUndo = !history.isEmpty; canRedo = false
    }
    func undo() { guard let value = history.popLast() else { return }; future.append(project); project = value; updateHistory() }
    func redo() { guard let value = future.popLast() else { return }; history.append(project); project = value; updateHistory() }
    private func updateHistory() { canUndo = !history.isEmpty; canRedo = !future.isEmpty }
    private func persist() {
        do { let data = try JSONEncoder().encode(project); try data.write(to: Self.autosaveURL, options: .atomic) }
        catch { notice = "Autosave failed: \(error.localizedDescription)" }
    }
    func setScale(_ value: Scale) { edit { $0.root = value.root; $0.scale = value.kind }; notice = "Exploring \(value.name). Existing progression stays in place." }
    func audition(_ chord: Chord) {
        selectedChord = chord
        audition(notes: chord.notes)
        notice = "\(chord.name) · \(chord.notes.map { Music.note($0) }.joined(separator: " · "))"
    }
    func audition(notes: [Int]) {
        guard !isPlaying else { return }
        do {
            let events = notes.enumerated().map { NoteEvent(note: $0.element, start: project.motion == .strum ? Double($0.offset) * 0.06 : 0, duration: 1.8) }
            let data = Synthesizer.wav(samples: Synthesizer.render(events: events, tempo: 120, beats: 2, instrument: instrument))
            preview = try AVAudioPlayer(data: data); preview?.volume = Float(volume)
            guard preview?.play() == true else { throw PlaybackError.unavailable }
            soundingNotes = Set(notes)
            let token = UUID(); previewToken = token
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in if self?.previewToken == token && self?.isPlaying == false { self?.soundingNotes = [] } }
        } catch { errorMessage = error.localizedDescription }
    }
    private var previewToken = UUID()
    func add(_ chord: Chord) {
        guard project.clips.count < 128 else { errorMessage = "A session can contain up to 128 chord clips."; return }
        let clip = Clip(chord: chord); edit { $0.clips.append(clip) }; selectedClip = clip.id; selectedChord = chord
        audition(chord)
    }
    func select(_ clip: Clip) { selectedClip = clip.id; audition(clip.chord) }
    func removeSelected() {
        guard let selectedClip else { return }; edit { $0.clips.removeAll { $0.id == selectedClip } }; self.selectedClip = nil
    }
    func duplicateSelected() {
        guard let id = selectedClip, let index = project.clips.firstIndex(where: { $0.id == id }), project.clips.count < 128 else { return }
        let copy = Clip(chord: project.clips[index].chord, beats: project.clips[index].beats)
        edit { $0.clips.insert(copy, at: index + 1) }; selectedClip = copy.id
    }
    func moveSelected(_ offset: Int) {
        guard let id = selectedClip, let index = project.clips.firstIndex(where: { $0.id == id }), project.clips.indices.contains(index + offset) else { return }
        edit { $0.clips.swapAt(index, index + offset) }
    }
    func changeClip(chord: Chord? = nil, beats: Double? = nil) {
        guard let id = selectedClip, let index = project.clips.firstIndex(where: { $0.id == id }) else { return }
        edit { if let chord { $0.clips[index].chord = chord }; if let beats { $0.clips[index].beats = beats } }
        if let chord { selectedChord = chord; audition(chord) }
    }
    func transpose(_ amount: Int) { edit { p in p.clips = p.clips.map { clip in var c = clip; c.chord = c.chord.transposed(amount); return c }; p.root = Music.pc(p.root + amount) } }
    func loadPreset(_ indices: [Int], name: String) {
        let chords = scaleChords
        guard !chords.isEmpty else { return }
        edit { p in p.clips = indices.map { Clip(chord: chords[$0 % chords.count]) }; p.name = name }
        selectedClip = project.clips.first?.id; notice = "Loaded \(name)."
    }
    func toggleKey(_ note: Int) {
        if inputNotes.contains(note) { inputNotes.remove(note) } else { inputNotes.insert(note) }
        if !inputNotes.isEmpty { audition(notes: inputNotes.sorted()) } else { preview?.stop(); soundingNotes = [] }
    }
    func receive(note: Int, down: Bool) {
        if down { inputNotes.insert(note) } else { inputNotes.remove(note) }
        if down { audition(notes: inputNotes.sorted()) }
    }
    func detectTypedNotes() {
        let notes = Music.parse(detectorText)
        guard !notes.isEmpty else { errorMessage = "Enter note names such as C4 E4 G4, or MIDI numbers such as 60 64 67."; return }
        inputNotes = Set(notes); audition(notes: notes)
    }
    func clearInput() { inputNotes = []; preview?.stop(); soundingNotes = [] }
    func toggleMIDIInput() {
        do { midiStatus = try midi.listen(!midiEnabled); midiEnabled.toggle(); if !midiEnabled { clearInput() } }
        catch { midiEnabled = false; errorMessage = error.localizedDescription }
    }
    func toggleMIDIOutput() {
        if midiOutput { midi.panic(); midiOutput = false; return }
        do { try midi.enableOutput(); midiOutput = true; notice = "Select ‘Harmonic Lab Out’ as a MIDI source in your DAW." }
        catch { errorMessage = error.localizedDescription }
    }
    func togglePlayback() { if isPlaying || isRendering { stop() } else { play() } }
    func play() {
        guard !project.clips.isEmpty else { notice = "Add a chord to the progression first."; return }
        let seconds = project.totalBeats * 60 / project.tempo
        guard seconds <= 180 else { errorMessage = "Playback and WAV rendering currently support up to 3 minutes per session. MIDI export supports the full progression."; return }
        preview?.stop(); soundingNotes = []; isRendering = true; notice = "Preparing audio…"
        let value = project; let voice = instrument; let token = UUID(); revision = token
        rendering = Task { [weak self] in
            let data = await Task.detached(priority: .userInitiated) {
                Synthesizer.wav(samples: Synthesizer.render(events: Arrangement.events(for: value), tempo: value.tempo, beats: value.totalBeats, instrument: voice))
            }.value
            guard let self, !Task.isCancelled, self.revision == token else { return }
            do {
                self.player = try AVAudioPlayer(data: data); self.player?.volume = Float(self.volume); self.player?.prepareToPlay()
                guard self.player?.play() == true else { throw PlaybackError.unavailable }
                self.isRendering = false; self.isPlaying = true; self.playhead = 0
                self.prepareMIDISchedule(value); self.notice = "Playing · \(Int(value.tempo)) BPM"
                self.timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in Task { @MainActor in self?.tick() } }
            } catch { self.isRendering = false; self.errorMessage = error.localizedDescription }
        }
    }
    private func prepareMIDISchedule(_ value: Project) {
        midiIndex = 0; midiNotes = []
        midiSchedule = []
        let secondsPerBeat = 60 / value.tempo
        for event in Arrangement.events(for: value) {
            midiSchedule.append((event.start * secondsPerBeat,event.note,true,event.velocity))
            midiSchedule.append(((event.start + event.duration) * secondsPerBeat,event.note,false,0))
        }
        midiSchedule.sort { a,b in
            if a.0 != b.0 { return a.0 < b.0 }
            return !a.2 && b.2
        }
    }
    private func tick() {
        guard let player, isPlaying else { return }
        let seconds = player.currentTime
        let end = project.totalBeats * 60 / project.tempo
        if seconds >= end || !player.isPlaying {
            midi.panic(); midiNotes = []
            if loop { player.currentTime = 0; player.play(); midiIndex = 0; playhead = 0; soundingNotes = []; return }
            stop(); return
        }
        playhead = seconds * project.tempo / 60
        while midiIndex < midiSchedule.count, midiSchedule[midiIndex].0 <= seconds {
            let event = midiSchedule[midiIndex]
            if midiOutput { midi.send(note: event.1, down: event.2, velocity: event.3) }
            if event.2 { midiNotes.insert(event.1) } else { midiNotes.remove(event.1) }
            midiIndex += 1
        }
        soundingNotes = midiNotes
    }
    func stop() {
        revision = UUID(); rendering?.cancel(); rendering = nil
        timer?.invalidate(); timer = nil; player?.stop(); preview?.stop()
        isPlaying = false; isRendering = false; playhead = 0; soundingNotes = []; midiNotes = []; midi.panic(); notice = "Stopped."
    }
    func newProject() { edit { $0 = Project() }; selectedClip = nil; inputNotes = []; notice = "New session. Choose a scale to begin." }
    func save() {
        guard !filePanelOpen else { return }; filePanelOpen = true; defer { filePanelOpen = false }
        let panel = NSSavePanel(); panel.allowedContentTypes = [UTType(filenameExtension: "harmonic") ?? .json]; panel.nameFieldStringValue = project.name + ".harmonic"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try JSONEncoder().encode(project).write(to: url, options: .atomic); notice = "Saved \(url.lastPathComponent)." } catch { errorMessage = error.localizedDescription }
    }
    func open() {
        guard !filePanelOpen else { return }; filePanelOpen = true; defer { filePanelOpen = false }
        let panel = NSOpenPanel(); panel.allowedContentTypes = [UTType(filenameExtension: "harmonic") ?? .json, .json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        openSession(url)
    }
    func openSession(_ url: URL) {
        do {
            guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) < 2_000_000 else { throw SessionError.invalid }
            let value = try JSONDecoder().decode(Project.self, from: Data(contentsOf: url)).validated()
            edit { $0 = value }; selectedClip = nil; notice = "Opened \(url.lastPathComponent)."
        } catch { errorMessage = error.localizedDescription }
    }
    func exportMIDI() {
        guard !filePanelOpen else { return }; filePanelOpen = true; defer { filePanelOpen = false }
        guard !project.clips.isEmpty else { return }
        let panel = NSSavePanel(); panel.allowedContentTypes = [.midi]; panel.nameFieldStringValue = project.name + ".mid"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try MIDIFile.encode(project: project).write(to: url, options: .atomic); notice = "Exported MIDI · \(project.clips.count) chords." } catch { errorMessage = error.localizedDescription }
    }
    func importMIDI() {
        guard !filePanelOpen else { return }; filePanelOpen = true; defer { filePanelOpen = false }
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.midi]; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 5_000_000 else { throw MIDIImportError.tooLarge }
            let imported = try MIDIImporter.decode(Data(contentsOf: url))
            edit { $0.clips = imported.clips; $0.tempo = imported.tempo; $0.name = url.deletingPathExtension().lastPathComponent }
            selectedClip = project.clips.first?.id
            notice = "Imported \(imported.clips.count) chord groups from \(imported.noteCount) MIDI notes. Tempo changes and leading rests are not retained."
        } catch { errorMessage = error.localizedDescription }
    }
    func importAudio() {
        guard !filePanelOpen else { return }; filePanelOpen = true; defer { filePanelOpen = false }
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.audio]; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        stop(); isAnalyzing = true; audioSegments = []; audioSource = url.lastPathComponent
        notice = "Analyzing up to the first 60 seconds of \(url.lastPathComponent)…"
        let token = UUID(); analysisRevision = token
        Task { [weak self] in
            do {
                let segments = try await Task.detached(priority: .userInitiated) {
                    let file = try AVAudioFile(forReading: url)
                    let format = file.processingFormat
                    guard format.sampleRate.isFinite,(8000...192000).contains(format.sampleRate),format.channelCount > 0,format.channelCount <= 8 else { throw AudioAnalysisError.invalid }
                    let length = min(file.length,AVAudioFramePosition(format.sampleRate*60))
                    guard length > 0,let buffer = AVAudioPCMBuffer(pcmFormat: format,frameCapacity: AVAudioFrameCount(length)) else { throw AudioAnalysisError.invalid }
                    try file.read(into: buffer,frameCount: AVAudioFrameCount(length))
                    guard let channels = buffer.floatChannelData else { throw AudioAnalysisError.invalid }
                    var mono = [Float](repeating: 0,count: Int(buffer.frameLength))
                    for channel in 0..<Int(format.channelCount) { for index in mono.indices { mono[index] += channels[channel][index] / Float(format.channelCount) } }
                    return try AudioChordAnalyzer.analyze(samples: mono,sampleRate: format.sampleRate)
                }.value
                guard let self,self.analysisRevision == token else { return }
                self.audioSegments = segments; self.isAnalyzing = false
                self.notice = "Found \(segments.count) approximate chord segments. Review by ear before adding."
            } catch {
                guard let self,self.analysisRevision == token else { return }
                self.isAnalyzing = false; self.errorMessage = error.localizedDescription
            }
        }
    }
    func useAudioSegments() {
        guard !audioSegments.isEmpty else { return }
        let clips = audioSegments.prefix(128).map { segment in Clip(chord: segment.chord,beats: min(16,max(0.5,((segment.end-segment.start) * project.tempo / 60 * 2).rounded()/2))) }
        edit { $0.clips = clips; $0.name = audioSource }
        selectedClip = clips.first?.id; notice = "Added approximate audio chords at the current tempo. Timing is quantized to half beats; gaps are removed."
    }
    func exportWAV() {
        guard !filePanelOpen else { return }; filePanelOpen = true; defer { filePanelOpen = false }
        guard !project.clips.isEmpty else { return }
        guard project.totalBeats * 60 / project.tempo <= 180 else { errorMessage = "WAV export supports up to 3 minutes per session."; return }
        let panel = NSSavePanel(); panel.allowedContentTypes = [.wav]; panel.nameFieldStringValue = project.name + ".wav"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        stop(); isRendering = true
        let value = project; let voice = instrument; let token = UUID(); revision = token
        rendering = Task { [weak self] in
            let data = await Task.detached(priority: .userInitiated) { Synthesizer.wav(samples: Synthesizer.render(events: Arrangement.events(for: value), tempo: value.tempo, beats: value.totalBeats, instrument: voice)) }.value
            guard let self, self.revision == token, !Task.isCancelled else { return }
            do { try data.write(to: url, options: .atomic); self.notice = "Exported WAV · \(url.lastPathComponent)." } catch { self.errorMessage = error.localizedDescription }
            self.isRendering = false
        }
    }
}
enum PlaybackError: LocalizedError { case unavailable; var errorDescription: String? { "Audio playback could not start. Check your macOS audio output." } }
