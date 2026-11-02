import SwiftUI
import HarmonicCore

struct InspectorView: View {
    @EnvironmentObject var m: AppModel
    private var chord: Chord { m.activeClip?.chord ?? m.selectedChord }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading,spacing: 20) {
                HStack { Text("CHORD INSPECTOR").font(.system(size: 9,weight: .semibold)).tracking(1.5); Spacer(); Image(systemName: "slider.horizontal.3") }.foregroundStyle(Studio.dim)
                VStack(alignment: .leading,spacing: 8) {
                    Text(chord.name).font(.system(size: 42,weight: .medium,design: .rounded)).minimumScaleFactor(0.5).lineLimit(1)
                    Text(m.activeClip == nil ? "Auditioning chord" : "Selected progression clip").font(.system(size: 10)).foregroundStyle(Studio.dim)
                    HStack(spacing: 5) { ForEach(chord.notes,id: \.self) { note in Text(Music.note(note)).font(.system(size: 10,weight: .medium,design: .monospaced)).padding(.horizontal,8).padding(.vertical,6).background(Studio.teal.opacity(0.1),in: RoundedRectangle(cornerRadius: 4)).foregroundStyle(Studio.teal) } }.padding(.top,8)
                }
                Rectangle().fill(Studio.line).frame(height: 1)
                VStack(alignment: .leading,spacing: 14) {
                    field("Root") {
                        Picker("Root",selection: Binding(get: { chord.root },set: { value in change { $0.root = value } })) { ForEach(0..<12,id: \.self) { Text(Music.note($0)).tag($0) } }.labelsHidden()
                    }
                    field("Color") {
                        Picker("Chord color",selection: Binding(get: { chord.quality },set: { value in change { $0.quality = value; $0.inversion = min($0.inversion,value.intervals.count-1) } })) { ForEach(ChordQuality.allCases) { Text($0 == .major ? "Major" : $0 == .minor ? "Minor" : $0.suffix).tag($0) } }.labelsHidden()
                    }
                    field("Inversion") {
                        Picker("Inversion",selection: Binding(get: { chord.inversion },set: { value in change { $0.inversion = value } })) { Text("Root").tag(0); ForEach(1..<chord.quality.intervals.count,id: \.self) { Text("\($0)").tag($0) } }.labelsHidden()
                    }
                    field("Octave") { Stepper(value: Binding(get: { chord.octave },set: { value in change { $0.octave = value } }),in: 1...5) { Text("\(chord.octave)").monospacedDigit() } }
                    if let clip = m.activeClip {
                        field("Length") { Picker("Clip length",selection: Binding(get: { clip.beats },set: { m.changeClip(beats: $0) })) { ForEach([0.5,1,2,4,8,16],id: \.self) { Text("\(String(format: "%g",$0)) beats").tag($0) } }.labelsHidden() }
                    }
                }.controlSize(.small)
                VStack(spacing: 8) {
                    Button { m.audition(chord) } label: { Label("Audition",systemImage: "speaker.wave.2").frame(maxWidth: .infinity) }.buttonStyle(StudioButton())
                    Button { m.add(chord) } label: { Label("Add to progression",systemImage: "plus").frame(maxWidth: .infinity) }.buttonStyle(StudioButton(active: true))
                }
                if m.activeClip != nil {
                    Rectangle().fill(Studio.line).frame(height: 1)
                    HStack(spacing: 6) { IconButton(icon: "arrow.left",help: "Move clip left") { m.moveSelected(-1) }; IconButton(icon: "arrow.right",help: "Move clip right") { m.moveSelected(1) }; Spacer(); IconButton(icon: "plus.square.on.square",help: "Duplicate clip") { m.duplicateSelected() }; IconButton(icon: "trash",help: "Delete clip") { m.removeSelected() } }
                }
                Rectangle().fill(Studio.line).frame(height: 1)
                VStack(alignment: .leading,spacing: 10) {
                    Text("TRY A DIFFERENT COLOR").font(.system(size: 8,weight: .semibold)).tracking(1.3).foregroundStyle(Studio.dim)
                    ForEach(alternatives,id: \.self) { quality in
                        Button { change { $0.quality = quality; $0.inversion = 0 } } label: {
                            HStack { Text(Music.note(chord.root) + quality.suffix).font(.system(size: 12,weight: .medium)); Spacer(); Text(quality.intervals.map { Music.note(chord.root+$0) }.joined(separator: " ")).font(.system(size: 8,design: .monospaced)).foregroundStyle(Studio.dim); Image(systemName: "arrow.up.right").font(.system(size: 9)).foregroundStyle(Studio.dim) }.padding(.vertical,6)
                        }.buttonStyle(.plain)
                    }
                }
                Text("Voicing changes apply to the selected clip. Changing key explores a new scale; use Transpose to move the progression.").font(.system(size: 10)).foregroundStyle(Studio.dim).lineSpacing(4)
            }.padding(20)
        }.background(Studio.sidebar).scrollIndicators(.hidden)
    }
    private var alternatives: [ChordQuality] {
        let minor = chord.quality.intervals.contains(3)
        return minor ? [.minor7,.minor9,.minor6,.minorAdd9] : [.major7,.add9,.sus2,.dominant9]
    }
    private func change(_ action: (inout Chord) -> Void) {
        var updated = chord; action(&updated)
        if m.activeClip != nil { m.changeClip(chord: updated) } else { m.audition(updated) }
    }
    private func field<Content: View>(_ title: String,@ViewBuilder content: () -> Content) -> some View {
        HStack { Text(title).font(.system(size: 11)).foregroundStyle(Studio.muted); Spacer(); content().frame(maxWidth: 120) }
    }
}

struct DetectionView: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        VStack(alignment: .leading,spacing: 12) {
            SectionHeading(letter: "A",title: "Detect",detail: "Notes → harmony") {
                Menu {
                    Button("Import MIDI chords…") { DispatchQueue.main.async { m.importMIDI() } }
                    Button("Analyze audio file…") { DispatchQueue.main.async { m.importAudio() } }
                } label: { Label("Import file",systemImage: "doc.badge.plus") }.menuStyle(.borderlessButton).fixedSize().disabled(m.isAnalyzing)
                Button { m.toggleMIDIInput() } label: { Label(m.midiEnabled ? "Listening" : "Connect MIDI",systemImage: m.midiEnabled ? "record.circle" : "pianokeys") }.buttonStyle(StudioButton(active: m.midiEnabled))
            }
            HStack(spacing: 8) { TextField("C4 E4 G4 · or 60 64 67",text: $m.detectorText).textFieldStyle(.plain).padding(9).background(Studio.sidebar,in: RoundedRectangle(cornerRadius: 5)).onSubmit { m.detectTypedNotes() }; Button("Detect",action: m.detectTypedNotes).buttonStyle(StudioButton()); Button("Clear",action: m.clearInput).buttonStyle(StudioButton()) }
            Text(m.midiEnabled ? m.midiStatus : "Enter notes, click the keyboard below, or connect a MIDI keyboard.").font(.system(size: 10)).foregroundStyle(Studio.dim)
            if m.matches.isEmpty {
                HStack(spacing: 12) { Image(systemName: "waveform.path").font(.system(size: 25,weight: .light)).foregroundStyle(Studio.dim); VStack(alignment: .leading,spacing: 5) { Text("A few notes can be the start of something.").font(.system(size: 12)); Text("Play at least two different notes to see chord candidates.").font(.system(size: 10)).foregroundStyle(Studio.dim) } }.frame(maxWidth: .infinity,alignment: .leading).padding(.vertical,20)
            } else {
                HStack(spacing: 8) {
                    ForEach(Array(m.matches.prefix(4))) { match in
                        VStack(alignment: .leading,spacing: 8) {
                            HStack { Text(match.name).font(.system(size: 21,weight: .medium,design: .rounded)); Spacer(); Button { m.add(match.chord) } label: { Image(systemName: "plus").frame(width: 20,height: 20) }.buttonStyle(.plain).accessibilityLabel("Add detected \(match.name)") }
                            Text(match.score == 1 ? "Exact pitch-class match" : "Partial pitch-class match").font(.system(size: 8)).foregroundStyle(Studio.dim)
                        }.padding(12).frame(maxWidth: .infinity).background(Studio.teal.opacity(0.07),in: RoundedRectangle(cornerRadius: 6)).overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Studio.line,lineWidth: 1))
                    }
                }
            }
            if !m.scaleMatches.isEmpty {
                HStack(spacing: 6) { Text("FITS IN").font(.system(size: 8,weight: .semibold)).foregroundStyle(Studio.dim); ForEach(Array(m.scaleMatches.prefix(3).enumerated()),id: \.offset) { _,match in Button(match.0.name) { m.setScale(match.0) }.font(.system(size: 10)).buttonStyle(.plain).foregroundStyle(Studio.teal).padding(.horizontal,7).padding(.vertical,5).background(Studio.panel,in: RoundedRectangle(cornerRadius: 4)) } }
            }
            if m.isAnalyzing { HStack { ProgressView().controlSize(.small); Text("Analyzing \(m.audioSource)…").font(.system(size: 11)).foregroundStyle(Studio.muted) }.padding(.vertical,10) }
            if !m.audioSegments.isEmpty {
                Divider().overlay(Studio.line)
                HStack { VStack(alignment: .leading,spacing: 4) { Text(m.audioSource).font(.system(size: 11,weight: .medium)); Text("Approximate chroma analysis · first 60 seconds · review by ear").font(.system(size: 9)).foregroundStyle(Studio.dim) }; Spacer(); Button("Use progression",action: m.useAudioSegments).buttonStyle(StudioButton()) }
                ScrollView(.horizontal) { HStack(spacing: 8) { ForEach(Array(m.audioSegments.enumerated()),id: \.offset) { _,segment in Button { m.audition(segment.chord) } label: { VStack(alignment: .leading,spacing: 6) { Text(segment.chord.name).font(.system(size: 17,weight: .medium)); Text(String(format: "%.1f–%.1fs",segment.start,segment.end)).font(.system(size: 9,design: .monospaced)).foregroundStyle(Studio.dim) }.padding(10).background(Studio.panel,in: RoundedRectangle(cornerRadius: 5)) }.buttonStyle(.plain) } } }.frame(height: 72)
            }
        }
    }
}
